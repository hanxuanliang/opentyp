#import "../cv.typ": * 

#show: cv.with(
  author: "SQL执行全流程"
)

RisingLight中 SELECT 语句的执行过程可以分解为以下几个步骤:

+ 解析：使用SQL解析器将输入的SQL字符串(例如: #codeText("SELECT a，sum(b) FROM t GROUP BY a"))解析成抽象语法树(AST)。此步骤在 src/sql_parser 目录中

+ 绑定：绑定程序分析AST以绑定必要信息，例如每个变量所属的表、它们的类型和相应列。此步骤可在src/binder目录中看到

+ 逻辑规划：然后将绑定语句映射到逻辑计划中，这是查询如何处理的基本草图。该逻辑计划包括：Projection、Aggregation、TableScan、Filter和Join等运算符。此步骤可在src/logical_planner目录中找到

+ 优化和物理规划：优化器通过选择每个逻辑运算符的最佳执行者，并应用在一些诸如：filter join、filter scan、constant folding等优化来将逻辑计划转换为物理计划

== egg::EGraph


#codeInline("egg::EGraph")\(来自egg库)是一种维护等价类并提供高效搜索和操作表达式框架的 `e-graph` 数据结构。它在 `Builder` 结构体的上下文中使用，负责为给定的查询计划构建执行器。

在该项目中egg::EGraph被用于存储Expr(表示查询计划的一部分)以及相关联的 `TypeSchemaAnalysis` 数据。
#codeText("TypeSchemaAnalysis") 反过来又持有目录引用，并用于类型检查和确定表达式输出模式。

Builder 使用 egg::EGraph 在执行器构建过程中执行各种操作，例如提取给定节点的 RecExpr、解析列索引、获取计划节点的输出类型以及从 e-graph 中包含的 RecExpr 构建查询最终执行器。e-graph 帮助管理查询计划，在执行器构建过程中提供对表达式及其相应元信息高效访问\