# SecondaryStorage 设计

SecondaryStorage中的catalog是RootCatalog的一个实例，它负责管理数据库模式的元数据，例如表及其列。该目录提供创建、删除和修改表以及管理和访问其元数据的方法。在SecondaryStorage的上下文中，目录用于在存储引擎操作期间维护和访问表的元数据信息。

## catalog的作用项

storage包括表模式、表名、列描述和表ID引用。SecondaryStorage中的目录存储为RootCatalogRef，它是对共享RootCatalog实例的引用。这允许在存储引擎的不同组件之间一致地共享目录信息。RootCatalog不仅保存表的元数据，还提供了根据其ID、schemaId或表名添加、删除和查找表的方法，使其成为管理SecondaryStorage中表元数据的中心点。

RootCatalog作为SecondaryStorage引擎中所有模式下所有表的元信息管理目录。它维护一个模式哈希映射（schema_idxs）、模式ID和SchemaCatalog实例。
SchemaCatalog实例在每个模式内保存与表相关的元数据。

RootCatalog提供了各种访问和管理表格的方法，例如：
- `get_schema_id_by_name`：根据名称获取模式ID
- `get_schema_by_id`：给定架构ID获取SchemaCatalog实例
- `get_schema_by_name`：给定架构名称获取SchemaCatalog实例
- `get_table`：给定TableRefId获取Arc<TableCatalog>
- `get_column`：给定ColumnRefId获取ColumnCatalog
- `add_table`：通过提供架构ID、名称、列、is_materialized_view和ordered_pk_ids向架构添加表格
- `drop_table`: 给出TableRefId从一个schema删除一张table
- `get_table_id_by_name`: 根据schema name 和 table name 获取 TableRefId

### schemaIds

schema_idxs是RootCatalog中的一种数据结构，它维护了模式名称（作为字符串）与其对应的SchemaIds（作为u32）之间的映射关系。它是一个HashMap<String, SchemaId>，用于根据模式名称查找模式ID，在具有模式名称时允许高效检索SchemaCatalog实例。该映射有助于管理模式级元数据，并提供快速访问模式ID以执行各种目录操作。

### SchemaCatalog

SchemaCatalog结构维护以下数据：
- id：唯一标识模式的SchemaId
- name：表示模式名称的字符串
- table_idxs：将表名映射到其相应的TableIds的HashMap<String，TableId>。这允许基于表名在模式内高效查找表ID
- tables：将表ID映射到其相应的表目录实例（TableCatalog）的HashMap<TableId，Arc<TableCatalog>>，它们存储表元数据
- next_table_id：存储模式内下一个可用表ID的TableId

SchemaCatalog提供添加和删除表以及通过其ID或名称检索表目录的方法。这些方法包括
- add_table
- delete_table
- all_tables
- get_table_id_by_name
- get_table_by_id
- get_table_by_name

通过管理模式中各个表格元数据，SchemaCatalog在组织和维护RisingLight项目目录方面发挥关键作用

### SchemaCatalog 与 RootCatalog 关系

SchemaCatalog作为RisingLight项目中分层目录结构的一部分工作，在该结构中RootCatalog是顶级目录，负责管理整个SecondaryStorage中所有模式。它维护了模式名称到模式ID（schema_idxs）的映射以及模式ID到相应SchemaCatalog实例的映射。

RootCatalog提供访问和管理模式的方法，例如get_schema_id_by_name、get_schema_by_id和get_schema_by_name等。而一旦拥有一个SchemaCatalog实例，就可以与其交互以管理特定架构内的表。

另一方面，SchemaCatalog负责管理单个架构内的所有表格。它具有各种方法来通过其ID或名称添加、删除和检索表格，正如我们在先前回答中提到的那样。

总之，RootCatalog和SchemaCatalog共同创建分层目录结构。 RootCatalog处理架构，而SchemaCatalog处理每个架构内部的表格，在RisingLight存储引擎中有效组织和管理数据库元数据。

## VersionManager

VersionManager管理存储引擎的状态历史记录，并清理磁盘上的陈旧文件。它通过为每个更改分配时代号来跟踪系统中的更改。它维护每个时代的快照，允许事务根据其需求固定和取消固定时代。当事务拍摄快照时，它会固定一个时代号；逻辑删除的RowSets直到快照取消固定该时代才会被物理删除。

VersionManager处理CreateTable、DropTable、AddRowSet、DeleteRowSet、AddDV和DeleteDV等操作。它在其VersionManagerInner结构中维护存储引擎的状态，具有像rowsets、dvs和ref_cnt这样的内部结构。它还管理清单文件以持久化更改，并支持清理陈旧文件。

将VersionManager与存储引擎分开设计是为了准备分布式存储引擎，在其中MetadataManager将执行类似任务。

### Compactor Handler

Compactor负责管理存储引擎中的压缩。它使用Arc<SecondaryStorage>和Receiver停止信号进行初始化。Compactor的主要功能在于compact_table方法，该方法将Snapshot和SecondaryTable作为参数。该方法首先选择要压缩的行集，确保它们的组合大小不超过存储选项中定义的目标行集大小。如果选择了多个行集，则按升序排列行集ID，并为每个行集创建迭代器。

根据表是否具有排序键，使用MergeIterator（如果存在排序键）或ConcatIterator（如果不存在排序键）组合迭代器。

然后，该方法使用统计聚合器计算不同值计数和行计数。根据此选择新行集的编码类型（如果不同值小于总行数的1/5，则为EncodeType :: Dictionary；否则为默认编码类型）。
然后使用所选编码类型创建一个新RowsetBuilder，并处理数据。

## TransactionManager

TransactionManager在RisingLight存储系统中确保快照隔离（SI）甚至可串行化快照隔离（SSI）方面发挥着关键作用。它负责管理表上的锁，确保并发删除和压缩操作不冲突，并在存储引擎中维护一致性。

TransactionManager具有lock_map，将表ID映射到其相应的锁定。它提供了try_lock_for_compaction、lock_for_compaction和lock_for_deletion等方法，以获取特定操作表的锁。通过使用这些锁定机制，TransactionManager协调并维护存储系统上多个并发操作之间的隔离。

### lock_map 结构

它将表ID映射到相应的锁。它是一个 `PLMutex<HashMap<u32, Arc<Mutex<()>>>>`。这意味着它是一个可变哈希映射，由parking_lot互斥体保护，其中键为表ID（u32），值为包含空元组的Arc-wrapped Mutexes。这使得TransactionManager能够单独处理每个表的锁定和同步，确保不同表上的并发操作不冲突，并可以隔离执行。

### 如何处理并发删除和压缩操作之间的冲突?

TransactionManager负责处理并发删除和压缩操作之间的冲突。它通过为每个表使用锁定机制来实现这一点。lock_map将表ID与其相应的锁相关联，确保每个表都有唯一的锁。

当需要在表上执行压缩或删除操作时，TransactionManager提供了获取该表适当锁定的函数：
1. try_lock_for_compaction：此函数尝试获取用于压缩的锁，并立即返回Option<OwnedMutexGuard<()>>。如果成功，则可以进行压缩操作；否则，暂时跳过该操作。

2. lock_for_compaction：此函数异步地获取用于压缩的锁，并等待直到可用为止。

3. lock_for_deletion：此函数异步地获取用于删除的锁，并等待直到可用为止。

通过使用这些锁定机制，TransactionManager确保在同一张表上进行并发删除和压缩操作不会产生冲突，并维护存储系统中不同操作之间的隔离性。
