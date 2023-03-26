# opendal 结构

该库设计的目标是简化和增强不同编程语言中的数据访问的库。它提供了 Rust Core、各种语言的绑定（C、Java、Node.js、Python 和 Ruby），以及名为 oli 的命令行界面（CLI）等组件。OpenDAL 允许开发人员通过统一 API 自由、轻松和高效地访问数据。

## operator

Operator是OpenDAL中所有公共异步API的入口点。它提供了对不同存储后端的抽象，并允许用户执行存储操作，如列出目录、读写文件和管理元数据。Operator被设计为高效处理异步操作，并可以使用不同的批处理限制进行定制。它还提供了一个阻塞方法来创建BlockingOperator以执行同步操作。

### 构建过程

operator是使用OperatorBuilder构建的。以下几种方法来创建OperatorBuilder：
- Operator::new(builder)：接受后端builder并在内部调用其build()方法：
`let op: Operator = Operator::new(builder)?.finish();`
- Operator::from_map(map)：接受HashMap<String, String>，并使用指定为类型参数的后端服务构造运算符：
`let op: Operator = Operator::from_map::<Fs>(map)?.finish();`

在上述任何一种方法中创建了OperatorBuilder之后，您可以使用layer()方法向operator添加layer，并最终调用finish()方法完成构建并获取Operator实例。

## 基本概念

### 如何理解Accessor?

Accessor是该库中的关键组件，负责抽象存储后端并为不同的存储系统提供统一接口。它定义了可用于与数据存储交互的操作，包括创建、读取、写入、删除和列出数据等。

1. 它是存储后端需要实现以与此库兼容的trait。
2. 它为各种操作定义异步和阻塞方法，例如创建、读取、写入、状态查询、删除、列表和扫描等。
3. 它具有用于处理实际数据传输和分页的readers、writers和pagers(可以理解为分页器)相关类型。

AccessorInfo提供有关底层后端的元数据，其中包括scheme（scheme）、根目录（root）、名称（name）等信息。

要使用Accessor，通常需要为您特定的存储后端创建其实现，并通过由Accessor trait提供的统一接口来使用该实现。这使得在不修改与数据存储交互代码的情况下轻松切换不同的存储系统成为可能。

### 如何理解layer?

layer用于修改或扩展Accessor的行为。它们遵循装饰器模式，并允许您以灵活的方式组合功能。

layer通常由两部分组成：
- XxxLayer：实现Layer trait并返回XxxAccessor作为Self::LayeredAccessor。
- XxxAccessor：实现了Accessor trait并由XxxLayer构建。

要使用layer，您需要创建一个XxxLayer实例，并调用layer()方法，将内部的Accessor传递进去。这将返回一个新的Accessor，其中包含该layer提供的附加功能。

大多数layer只实现了一小部分Accessor方法。因此，强烈建议实现LayeredAccessor trait，它会自动转发所有未实现的方法到内部的 Accessor 中。
