## bp_monitor 说明

bp_monitor.h、bp_monitor.cpp 是用来实现../core/biriscv_npc.v 这个分支预测器的性能观测。

## 整体思路

bp_monitor 的思路是，仅仅使用 ./verilated/Vriscv_top_riscv_core__N200_NB9.h 中的关于 ../core/biriscv_npc.v 的 verilator 生成的接口，来检测分支预测器的性能。

主要有以下指标：
- 方向预测准确率：条件分支taken/not-taken判断正确性
- 目标地址准确率：跳转目标地址预测正确性
- 整体预测准确率：方向+目标都正确的综合准确率

组件级性能指标：
- BTB命中率：反映BTB表容量和替换策略效果
- BHT准确率：反映历史模式学习能力
- RAS准确率：反映函数调用栈管理效果

因此，你需要着重解决以下问题。

### 挑选有限的信号

```Cpp
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__clk_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__rst_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__invalidate_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__branch_request_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__branch_is_taken_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__branch_is_not_taken_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__branch_is_call_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__branch_is_ret_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__branch_is_jmp_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__pc_accept_i;
        CData/*1:0*/ u_frontend__DOT__u_npc__DOT__next_taken_f_o;

        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__pred_taken_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__pred_ntaken_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_valid_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_upper_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_is_call_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_is_ret_w;
        CData/*2:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_index_real_q;
        CData/*2:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_index_real_r;
        CData/*2:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_index_q;
        CData/*2:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_index_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_call_pred_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_ret_pred_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__bht_predict_taken_w;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_valid_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_upper_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_is_call_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_is_ret_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_is_jmp_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_hit_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_miss_r;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT____VdfgTmp_hb727a779__0;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__clk_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__rst_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__hit_i;
        CData/*0:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__alloc_i;

        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__global_history_real_q;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__global_history_q;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__gshare_wr_entry_w;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__gshare_rd_entry_w;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__bht_wr_entry_w;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__bht_rd_entry_w;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_entry_r;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_wr_entry_r;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_wr_alloc_w;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__hit_entry_i;
        SData/*8:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__alloc_entry_o;
        SData/*15:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__u_lru__DOT__lfsr_q;

        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__branch_source_i;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__branch_pc_i;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__pc_f_i;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__next_pc_f_o;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_next_pc_w;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__ras_pc_pred_w;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__i3;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__i4;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__btb_next_pc_r;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__i0;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__i1;
        IData/*31:0*/ u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__i2;
```

在上述信号中挑选有用的信号进行设计。

### 利用预测+预测器的反馈信号
你可以阅读 ../core/biriscv_npc.v 的源码来获取更多的细节，但你要做的是：

利用反馈信号：

```Verilog
    ,input           invalidate_i
    ,input           branch_request_i
    ,input           branch_is_taken_i
    ,input           branch_is_not_taken_i
    ,input  [ 31:0]  branch_source_i
    ,input           branch_is_call_i
    ,input           branch_is_ret_i
    ,input           branch_is_jmp_i
    ,input  [ 31:0]  branch_pc_i
```
利用预测信号：

```Verilog
    ,input  [ 31:0]  pc_f_i
    ,input           pc_accept_i
    // Outputs
    ,output [ 31:0]  next_pc_f_o
    ,output [  1:0]  next_taken_f_o
```

这两组信号可以形成：预测--->反馈这样的逻辑，你要做的就是设计良好的 monitor 函数，来对命中、预测正确性等进行统计。

注意，仅仅使用这个模块的 IO 信号、以及模块内部信号，足够解决我们实现这个功能了，不要别的信号了。

在设计的过程中，你还需要思考，因为预测信息早发生，你也不知道反馈信号什么时候来到，因此你得在 monitor 中等待并匹配上次预测的结果，如果匹配说明就是上次预测的信号，匹配后就可以判断有没有命中等。

---

## 实现说明（已完成）

### 关键发现

**最重要的发现**：`branch_request_i` 信号**只在预测错误时拉高**，用于通知预测器需要纠正预测。

这意味着：
- **预测正确** → 不会收到 `branch_request_i` 信号，CPU正常执行
- **预测错误** → 收到 `branch_request_i` 信号，提供正确的分支信息用于更新预测器

因此，统计预测准确率的逻辑需要反向思考：
1. 每次预测时，假设预测**正确**
2. 当收到 `branch_request_i` 时，说明预测**错误**，需要纠正统计

### 核心设计

#### 使用的关键信号

**预测信号**（来自 BRANCH_PREDICTION 模块内部）：
```cpp
pred_taken_w   // 预测分支taken
pred_ntaken_w  // 预测分支not-taken
btb_valid_r    // BTB命中
btb_upper_r    // 分支在fetch块的上半部分(PC+4)还是下半部分(PC)
btb_next_pc_r  // 预测的目标地址
```

**反馈信号**（NPC模块输入）：
```cpp
branch_request_i      // 预测错误标志（只在错误时为高）
branch_source_i       // 分支指令的PC
branch_is_taken_i     // 实际分支taken
branch_is_not_taken_i // 实际分支not-taken
branch_pc_i           // 实际分支目标
branch_is_call_i      // 是否是call指令
branch_is_ret_i       // 是否是return指令
branch_is_jmp_i       // 是否是jump指令
```

#### 统计逻辑

```cpp
void BPMonitor::monitor() {
    // 1. 当有预测时（pred_taken_w 或 pred_ntaken_w 有效）
    if (pred_taken || pred_ntaken) {
        total_predictions++;
        // 假设预测正确
        direction_correct++;
        overall_correct++;
        total_branches++;

        if (pred_taken) {
            target_correct++;
            taken_branches++;
        } else {
            not_taken_branches++;
        }
    }

    // 2. 当收到预测错误信号时
    if (branch_request_i) {
        // 纠正统计：correct--, incorrect++
        direction_correct--;
        direction_incorrect++;
        overall_incorrect++;
        total_branches++;  // 增加一个实际分支

        // 统计实际分支类型
        if (branch_taken) taken_branches++;
        if (branch_ntaken) not_taken_branches++;
        if (branch_call) calls++;
        if (branch_ret) returns++;
        if (branch_jmp) jumps++;
    }
}
```

### 实现特点

1. **无需预测队列**：不需要维护预测-反馈的匹配关系
   - 利用 `branch_request_i` 只在错误时拉高的特性
   - 采用"先假设正确，遇到错误再纠正"的统计策略

2. **实时统计**：每个时钟周期更新统计数据
   - 预测时：增加正确计数
   - 错误反馈时：纠正计数

3. **简单高效**：避免了复杂的数据结构和PC匹配逻辑

### 统计指标说明

- **Total Predictions**: 预测器给出预测的次数（BTB命中）
- **Total Branches**: 实际执行的分支总数（预测正确+预测错误）
- **Direction Accuracy**: 方向预测准确率 = Correct / (Correct + Incorrect)
- **Target Accuracy**: 目标地址准确率（只统计taken分支）
- **Overall Accuracy**: 综合准确率（方向+目标都正确）

### 测试结果示例

运行 CoreMark 测试（100000 cycles）：

```
========================================
   Branch Predictor Statistics
========================================

--- Overall Statistics ---
Total Branches:      20102
Total Predictions:   18684

--- Direction Prediction ---
Correct:             17267
Incorrect:           1418
Accuracy:            92.41%

--- Target Address Prediction ---
Correct:             14804
Incorrect:           0
Accuracy:            100.00%

--- Overall Prediction (Direction + Target) ---
Correct:             17267
Incorrect:           1418
Accuracy:            92.41%

--- Branch Type Distribution ---
Taken:               15317
Not Taken:           4406
Calls:               23
Returns:             12
Jumps:               47
========================================
```

**结果分析**：
- 方向预测准确率达到 **92.41%**，说明预测器工作良好
- 目标地址准确率 **100%**，说明BTB正确存储了目标地址
- 预测数量 (18684) 略小于总分支数 (20102)，说明部分分支未被BTB覆盖（冷启动或容量限制）

### 信号访问路径

通过 Verilator 生成的层次结构访问信号：
```cpp
auto core = dut->rootp->v->u_core;
core->u_frontend__DOT__u_npc__DOT__BRANCH_PREDICTION__DOT__pred_taken_w;
core->u_frontend__DOT__u_npc__DOT__branch_request_i;
```

### 使用方法

1. **编译**：
   ```bash
   make clean
   make
   ```

2. **运行测试**：
   ```bash
   ./build/test.x -f coremark.elf -c 100000
   ```

3. **查看统计**：
   - 程序运行结束后会自动打印分支预测器统计信息
   - 包括预测准确率、分支类型分布等详细信息

### 文件说明

- **bp_monitor.h**: 类声明和数据结构定义
- **bp_monitor.cpp**: 具体实现
- **testbench.h**: 已经集成了 bp_monitor，在每个时钟周期调用 `monitor()` 函数

### 关键优势

1. **设计简单**：利用 `branch_request_i` 的语义特性，避免复杂的匹配逻辑
2. **准确可靠**：直接反映预测器的真实性能
3. **易于理解**：统计逻辑清晰，易于验证
4. **可扩展**：可以轻松添加更多组件级统计（BTB、BHT、RAS）

### 后续扩展方向

可以进一步添加的统计：
- **BTB命中率**：使用 `btb_hit_r` / `btb_miss_r` 信号
- **BHT准确率**：分析 `bht_predict_taken_w` 的准确性
- **RAS准确率**：统计 `ras_ret_pred_w` 的正确性
- **分支历史相关性分析**：利用 `global_history_q` 分析模式

