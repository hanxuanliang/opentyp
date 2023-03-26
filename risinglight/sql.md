# SQL执行

RisingLight中SELECT语句的执行过程可以分解为以下几个步骤：
1. 解析：使用SQL解析器将输入的SQL字符串（例如SELECT a，sum(b) FROM t GROUP BY a）解析成抽象语法树（AST）。此步骤可在src/sql_parser目录中找到。

2. 绑定：绑定程序分析AST以绑定必要信息，例如每个变量所属的表、它们的类型和相应列。此步骤可在src/binder目录中看到。

3. 逻辑规划：然后将绑定语句映射到逻辑计划中，这是查询如何处理的基本草图。该逻辑计划包括Projection、Aggregation、TableScan、Filter和Join等运算符。此步骤可在src/logical_planner目录中找到。

4. 优化和物理规划：优化器通过选择每个逻辑运算符的最佳执行者，并应用诸如filter join、filter scan、constant folding等优化来将逻辑计划转换为物理计划。

## parse(sql)

在循环处理多个子语句时，为每个子语句创建一个新的绑定器是必要的，以确保每个子语句的绑定是独立和相互分离的。这一点非常重要，因为不同的子语句可能具有不同的作用域和变量绑定，并且它可以防止在处理过程中出现冲突或副作用。

通过在循环内为每个子语句创建一个新的绑定器，您可以使每个子语句独立地进行处理、适当地进行范围限制，并拥有自己一组对象引用和变量绑定。这种方法有助于在处理可能涉及不同数据库对象或具有不同上下文的多个子语句时保持一致性和准确性。

## binder.bind(stmt)

binder.bind() 负责处理SQL语句并将其转换为适合进一步查询执行阶段（如优化和执行）的形式。

该函数主要解析语句中对数据库对象（如表和列）的名称和引用，确保查询依赖于目录中指定的有效对象。
以下是binder.bind函数的执行过程：

1. 它以Statement作为输入，这是表示抽象语法树(AST)形式的解析SQL语句
2. bind函数调用bind_stmt方法，根据其类型（例如SELECT、INSERT、UPDATE等），处理输入语句并将其转换为包含已解决数据库对象引用的绑定语句
3.  根据语句类型，bind_stmt函数调用相应的绑定器方法，例如bind_create_table、bind_drop、bind_insert、bind_delete、 bind_copy 和 bind_query来处理特定声明绑定需求
4. 这些绑定方法进一步处理声明，解析对象引用并构建最终表示声明的egg::EGraph。

### egg::EGraph

在 RisingLight 项目中，egg::EGraph 在 Builder 结构体的上下文中使用，负责为给定的查询计划构建执行器。egg::EGraph(来自 egg 库)是一种维护等价类并提供高效搜索和操作表达式框架的 e-graph 数据结构。

在该项目中，egg::EGraph 被用于存储 Expr(表示查询计划的一部分)以及相关联的 TypeSchemaAnalysis 数据。TypeSchemaAnalysis 反过来又持有目录引用，并用于类型检查和确定表达式输出模式。

Builder 使用 egg::EGraph 在执行器构建过程中执行各种操作，例如提取给定节点的 RecExpr、解析列索引、获取计划节点的输出类型以及从 e-graph 中包含的 RecExpr 构建查询最终执行器。e-graph 帮助管理查询计划，在执行器构建过程中提供对表达式及其相应元信息高效访问。

- extractor.find_best()

    extractor.find_best()在优化过程中用于基于成本找到最佳表达式(即查询计划)。它以 e-graph 和成本函数作为输入，并在优化后的 e-graph 中搜索具有最低成本的表达式。
    该函数工作如下：
    1. 使用 egg::Extractor 结构，通过传入 e-graph 和成本函数来构造
    2. 调用 find_best 函数并提供要优化的表达式的根 ID
    3. 该函数搜索 e-graph，考虑各种等效表达式，并根据提供的成本函数选择具有最低成本的表达式
    4. 该功能输出一个元组，其中包含找到的最低费用和相应的最佳表达式（作为 RecExpr）
    5. 然后可以将此最佳表达式用于查询执行过程中进一步阶段，例如查询计划构建和实际查询执行。寻找最佳表达式旨在减少执行查询所需的资源和时间，从而改善数据库系统性能。

- define_language! macro

    define_language 宏用于定义表示表达式和查询计划的 e-graph 语言。它有助于定义可用于构建查询计划并使用 egg 库提供的 e-graph 数据结构处理表达式。

    通过使用 define_language 宏，该项目指定了语言结构，如值（常量、列、表等）、实用程序（ref、list）、二元操作、一元操作、函数、聚合和与计划相关的表达式。这些结构形成了 RisingLight 数据库系统优化和执行阶段中查询计划表示和操作的基础。

    define_language 宏定义的 e-graph 语言简化了项目中查询计划的表示和操作，并帮助 egg 库无缝地与为数据库系统量身定制的特定语言结构配合工作。

- Expr

    使用define_language宏来表示项目中的表达式和查询计划。Scan表达式代表了一个表扫描操作，该操作从数据库中检索并获取特定表中的所有行。

    Expr中扫描的结构由TableRefId参数组成，该参数唯一标识要扫描的表。在执行阶段，TableScanExecutor使用此TableRefId执行实际的表扫描操作，在数据库中检索指定表中的所有行。

## executor_v2

executor_v2 模块中的构建函数负责为给定的查询计划构造执行器。执行器是一个 Result<DataChunk, ExecutorError> 类型的封装流，可用于以流式方式处理查询并生成最终结果集。构建函数接受 RootCatalogRef 目录引用、Arc 封装的 Storage 实现和表示查询计划的 RecExpr 作为输入参数。

###  executor_v2::build()

构建函数的主要步骤如下：
1. 通过调用 Builder::new(catalog, storage, plan) 创建新 Builder 实例。这将使用提供的目录、存储和查询计划初始化 Builder。
2. 在 Builder 实例上调用 build 方法。该方法遍历查询计划的 RecExpr 表示形式，并基于 Expr 节点构建相应的执行器树。
3. 在整个 build 方法过程中，Builder 根据 Expr 节点调用各种执行器构造函数，例如 TableScanExecutor、ProjectionExecutor、FilterExecutor、OrderExecutor 和 LimitExecutor 等等。

### TableScanExecutor

它扫描指定的表并检索所有行，如果提供了可选的过滤表达式，则应用该表达式。TableScanExecutor使用PhysicalTableScan计划、可选的BoundExpr进行过滤，并引用Storage实现进行初始化。

以下是TableScanExecutor执行过程的概述：

1. 首先调用execute方法，该方法内部调用execute_inner方法

2. execute_inner方法通过PhysicalTableScan计划中可用的表引用ID从存储中检索出表对象

3. 构建一个空块来处理没有返回行的情况

4. 使用read方法打开要读取的表，生成Transaction对象

5. 收集列索引以按指定顺序检索列，包括必要时的行处理程序

6. 通过在Transaction对象上调用scan方法创建TxnIterator，提供诸如列索引、过滤器表达式和排序信息等参数

7. 然后使用迭代器以流方式从表中获取数据块。这些块由异步流产生

### ProjectionExecutor

项目表达式数组(project_expressions)和一个子执行器(child)作为其输入。ProjectionExecutor将给定的项目表达式应用于由子执行器产生的输入数据的每一行，相应地转换数据。

以下是ProjectionExecutor执行过程的概述：
1. 它首先调用execute方法，这是一个异步函数，返回DataChunks流
2. 该方法进入循环以消耗子执行器的输出。它从子执行器检索数据块，并使用for_await逐个处理它们
3. 对于来自子执行器的每个输入数据块，ProjectionExecutor迭代project_expressions并评估每个表达式与输入数据块
4. 评估后的表达式结果被收集到新块中，然后由异步流生成并成为输出部分之一
5. 此过程继续直到来自子执行程序的输入数据耗尽。ProjectionExecutor 的结果输出流包括基于所应用项目表达式进行转换后得出的转换后数据块。

- 设计的目的是什么?

    ProjectionExecutor 设计的目的是在查询执行过程中对输入数据执行投影操作。投影操作通过选择特定列、计算新值或将函数应用于每行数据的列来转换输入数据。

    ProjectionExecutor 的设计旨在实现以下目标：
    1. 流处理：通过实现异步基于流的设计，ProjectionExecutor 以流式方式处理输入数据，允许有效地使用内存，并在处理大量数据时提高性能

    2. 模块化和可组合性：ProjectionExecutor 在执行器层次结构中作为模块化组件工作，仅专注于执行投影操作。它可以轻松地与其他执行器(如 TableScanExecutor、FilterExecutor 等)结合使用，以实现复杂的查询处理管道

    3. 灵活性：ProjectionExecutor 支持广泛的投影表达式，使其能够处理各种类型的输入数据变换和操作(例如选择特定列、计算新值、应用函数等)

    4. 可扩展性：ProjectionExecutor 的设计允许它在需要时并行高效地处理输入数据，并利用异步和并发处理技术来提高性能和可扩展性

其中还反复使用 `#[for_await]`。该宏的作用为:

与JavaScript中用于异步迭代器的for await语法相当的是 `while let Some(item) = stream.next().await`。这个循环允许你以异步方式遍历流，在流耗尽之前产生项。`stream.next().await` 会以非阻塞方式等待下一个可用项或输入流完成。

在先前提到过的ProjectionExecutor上下文中，该结构被用于以流式方式处理子执行程序传递过来的数据块。它可以异步地检索和处理数据，从而在处理大量数据时实现更高效地内存使用和更好地性能表现。

## planner

在RisingLight项目中的过程。从逻辑执行计划到物理执行计划的转换涉及将基于查询高级逻辑表示的逻辑计划运算符转换为更专注于实际实现细节和执行策略的相应物理计划运算符。

这种转换之所以至关重要，原因如下：
1. 优化：逻辑执行计划在关系代数方面进行了优化，并且不涉及低级别实现细节。将其转换为物理执行计划使系统能够考虑访问方法、连接算法和硬件资源等因素，以根据实际实现进一步优化执行策略

2. 可行性：逻辑执行计划是查询的抽象表示，可能不包含足够直接执行查询所需的信息。将其转换为物理执行计划提供必要的低级别详细信息（例如特定算法和技术），使系统可以通过该方案来直接对查询进行处理

3. 资源管理：物理执行计划考虑硬件资源（例如内存和CPU使用情况），允许系统在查询执行期间更好地管理这些资源，从而导致更有效率地处理。

4. 独立实现：通过分离逻辑和物理执行计划，它允许系统在处理过程中专注于查询的逻辑方面。

### 逻辑执行计划与物理执行计划的转换

逻辑执行计划通过 `PhysicalConverter`结构转换为物理执行计划。当在不同的逻辑计划节点上调用`PhysicalConverter`的方法(如rewrite_*方法)时，就会发生这种情况。该转换发生在优化阶段，在查询实际执行之前。

## 函数分析

main()循环接受来自终端的args[]:

    - newDB: `db = Database::new_on_disk()` 作为后续操作的DB对象
        - interactive(): 进入交互模式【终端传入sql:String】
        - read_sql: return sql
        - run_query_in_background(db, sql)
            - db.run(&sql)

现在来看看核心的 `db.run(&sql)` :

- parse(sql): 解析sql->Statement
