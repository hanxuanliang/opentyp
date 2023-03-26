# 数据结构的设计

> learn from: https://github.com/risinglightdb/risinglight/blob/main/docs/06-storage-basics.md

## 数据存储

数据在RisingLight中以列的形式存储。这里，一列被称为“数组”。Array是所有数组上的特征，指定了所有数组的接口。PrimitiveArray<T>实现了Array trait，其中T可以是bool、i32等。ArrayImpl是不同数组的枚举类型。

ArrayBuilder是构建器数组上的特征，用于构建Array。类似于PrimitiveArray<T>实现了Array一样，PrimitiveArrayBuilder<T>实现了 ArrayBuilder 。 ArrayBuilderImpl 是不同阵列生成器上的枚举类型。下面显示了一些字段/方法：

总结整体的数据设计：

- 数组表示内存中的一列

- DataChunk 表示一组连续的行，实现为 Array 的集合

- MemTable 是一个内存写缓冲区。append 接受 DataChunk。flush 输出 DataChunk

- SecondaryMemRowset<M: MemTable> 是一个将数据刷新到二级存储器的 mem-table。append 将其添加到其 MemTable 中。flush 将由 MemTable 返回的 DataChunk 刷新到磁盘上作为 EncodedRowset

- EncodedColumn 表示要持久化到二级存储器的列。它包含列的索引和数据信息。ColumnBuilder 在 append 时使用数组，在 flush 时输出 EncodedColumn，大致如此

- EncodedRowset 是一组编码后的列集合，其中 RowsetBuilder 在内部使用了 ColumnBuilder 。RowsetBuilder 在 append 时接受 DataChunk，在 flush 时输出 EncodedRowset.

## Array和ArrayBuilder

Array和ArrayBuilder之间的关系是通过它们的相关类型和它们所服务的目的来定义的。
- Array：在RisingLight中表示一列，将数据存储为数组。 Array trait为所有数组提供了一个公共接口。
- ArrayBuilder：负责构建Arrays。 ArrayBuilder trait为所有数组构建器提供了一个公共接口。

在Array trait中，有一个称为Builder的相关类型，对应于该Array特定实现所需的具体ArrayBuilder实现。同样，在ArrayBuilder trait中，有一个称为Array 的相关类型，对应于该 Array Builder 特定实现所需的具体 Array 实现。

当构建一个数组时，通常会使用 Array Builder 添加值，并调用 finish() 或 take() 方法创建最终数组。这些方法确保以一致且方便的方式创建各种类型的 Arrays.

### 设计的目的?

这个设计的目的是通过Array和ArrayBuilder特性提供一种模块化、一致且高效的处理列式存储方式。这个设计的主要优点包括：
1. 抽象：通过分离Array和ArrayBuilder的职责，该设计提供了明确的关注点分离。 Array特性负责表示列数据，而ArrayBuilder特性管理数组构建。这使得代码更易于理解、维护和扩展
2. 灵活性：该设计允许不同实现的数组和数组生成器无缝集成，支持各种数据类型、存储格式和优化
3. 类型安全：通过使用相应生成器和数组的相关联类型，该设计确保针对特定类型的数组使用正确生成器，在编译时防止潜在类型相关错误
4. 性能：可以为具体数据类型和用例优化实现Array 和 ArrayBuilder ，从而提高性能并减少内存使用量。此外，列式存储通常可实现有效查询处理、压缩以及矢量操作

总体而言，在RisingLight中所采用 的 Array 和 ArrayBuilder 设计有助于构建一个模块化、高效且多功能 的列式存储系统。

### 如何使用 ArrayBuilder?

ArrayBuilder用于创建和构建表示数据存储中列的数组。以下是一些值得注意的用法：
1. DataChunkBuilder：它利用ArrayBuilder实现来构建DataChunks，这是数据块的表示形式。 DataChunkBuilder持有一个ArrayBuilderImpl向量，并使用push_row或push_str_row方法添加行。当块达到其容量时，take()方法通过调用各个数组生成器上的take()方法来创建DataChunk。

2. CSV Reader：在读取CSV文件时，使用ArrayBuilder实现将解析后的数据转换并存储到适当的数组中。随着从CSV读取行，数据被推入相应的数组生成器中。

3. MemTable：在MemTable特征的BTreeMapMemTable实现中，在刷新数据以从内部B树映射保留行创建DataChunk时使用了ArrayBuilder。使用列类型信息创建数组生成器，然后将数据从行推入数组生成器以创建最终的DataChunk

4. Convert Functions：在某些情况下，需要将数据从一种类型转换为另一种类型。 ArrayBuilder实现用于创建目标数组以进行数据类型转换。

在这些上下文中使用ArrayBuilder有助于简化在RisingLight项目中创建、存储和操作列式数据过程，并提供一致接口并启用特定数据类型和用例优化。
