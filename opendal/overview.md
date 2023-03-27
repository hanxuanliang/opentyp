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

### 如何理解类型擦除?

在这个项目中使用类型擦除的结构是TypeEraseLayer。

TypeEraseLayer 的设计理念是提供一种方法来擦除底层 Accessor 的通用类型，同时保留其功能。当处理异构的 accessor 集合或应用具有不同类型的多个层时，并且您想避免与泛型相关的问题时，这尤其有用。

TypeEraseLayer 通过实现 Layer<A> trait 来实现此目标，其中 A 是底层 Accessor 的类型。相应的 TypeEraseAccessor<A> 包装内部 accessor 并实现了 LayeredAccessor trait。
使用 TypeEraseLayer 时，它会使用 TypeEraseAccessor<A> 包装内部 accessor 并在过程中擦除泛型类型。因此，accessor 的功能仍然可用，但不会暴露原始泛型类型。这简化了处理具有不同类型的 accessors，并使更加统一和灵活地处理它们变得更容易。

而TypeEraseLayer是在OperatorBuilder结构体的finish()方法中内部使用的。
当你在OperatorBuilder上调用finish()方法时，它会将TypeEraseLayer应用于accessor，这就得到一个被擦除了类型信息并包装在TypeEraseAccessor中的accessor。然后使用此accessor创建Operator实例。这允许您在整个应用程序中与不同的访问器和层进行无缝且简化交互，而无需处理复杂的通用类型。

TypeEraseAccessor结构体是一个包装器，用于擦除其泛型类型并保留其功能的基础Accessor。它与TypeEraseLayer一起使用，在Operator构建过程中提供类型擦除。
以下结构：
```rust
pub struct TypeEraseAccessor<A: Accessor> {
    inner: A,
}
```
这里，A表示要包装的基础访问器的类型。

TypeEraseAccessor实现了LayeredAccessor特征，其中包括read、write、list和scan等方法。在每个方法中，来自内部访问者方法的结果都会被用type-erased reader、writer和pager对象（oio::Reader、oio::Writer和oio::Pager）进行封装。
data

### LayeredAccessor 设计

LayeredAccessor设计的目的是简化使用层时为Accessor trait实现装饰器的过程。它提供了一种机制，可以自动将所有未实现的Accessor trait方法转发到内部访问器。这使您只需实现要修改或扩展的方法，而无需定义分层访问器中的每个方法。

以下是LayeredAccessor的设计思路：
1. LayeredAccessor是Accessor的子trait，这意味着它继承了所有Accessor方法
2. 它添加了一个关联类型Inner: Accessor来表示被装饰的内部访问器
3. 它提供了一个必需的方法`fn inner(&self) -> &Self::Inner`，该方法返回对内部访问器的引用。

当您为自定义Accessor实现LayeredAccessor trait时，您只需要实现要修改或扩展的方法即可。由于LayeredAccessor trait中提供了默认实现，因此所有其他方法都会自动转发到内部访问器。这种设计有助于减少样板代码，并使层次结构仅集中在需要更改或扩展的方法上。
