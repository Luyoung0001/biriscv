//-----------------------------------------------------------------
//                         biRISC-V CPU
//                     Next PC Generator Wrapper
//-----------------------------------------------------------------
// This module wraps biriscv_npc and maintains the PC register.
//
// Assumption: biriscv_npc is 2-cycle latency
//   - Cycle N:   receives pc_f_i
//   - Cycle N+1: outputs next_pc_f_o (valid)
//
// Timing:
//   Cycle 1: pc_q = A, send to npc, query_sent = 0 -> 1
//   Cycle 2: npc returns next_pc = B, valid_o = 1
//            If ready_i = 1: handshake, pc_q -> B, query_sent -> 0
//   Cycle 3: pc_q = B, send to npc, query_sent = 0 -> 1
//   Cycle 4: npc returns next_pc = C, valid_o = 1
//   ...
//
// Handshake: valid_o / ready_i
//-----------------------------------------------------------------

module biriscv_npcg
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_BRANCH_PREDICTION = 1
    ,parameter NUM_BTB_ENTRIES  = 32
    ,parameter NUM_BTB_ENTRIES_W = 5
    ,parameter NUM_BHT_ENTRIES  = 256
    ,parameter NUM_BHT_ENTRIES_W = 8
    ,parameter RAS_ENABLE       = 1
    ,parameter GSHARE_ENABLE    = 0
    ,parameter BHT_ENABLE       = 1
    ,parameter NUM_RAS_ENTRIES  = 8
    ,parameter NUM_RAS_ENTRIES_W = 3
    ,parameter RESET_VECTOR     = 32'h80000000
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           invalidate_i

    // Branch redirect (from execute stage)
    ,input           branch_request_i
    ,input           branch_is_taken_i
    ,input           branch_is_not_taken_i
    ,input  [ 31:0]  branch_source_i
    ,input           branch_is_call_i
    ,input           branch_is_ret_i
    ,input           branch_is_jmp_i
    ,input  [ 31:0]  branch_pc_i

    // Handshake with Fetch (downstream)
    ,input           ready_i

    // Outputs to Fetch
    ,output [ 31:0]  pc_o              // Current PC for Fetch
    ,output          valid_o           // PC is valid
    ,output [  1:0]  pred_branch_o     // Branch prediction info
);

//-----------------------------------------------------------------
// Internal PC Register
//-----------------------------------------------------------------
reg [31:0] pc_q;

//-----------------------------------------------------------------
// Wires from biriscv_npc
//-----------------------------------------------------------------
wire [31:0] next_pc_w;
wire [1:0]  next_taken_w;

//-----------------------------------------------------------------
// Query tracking
// Since biriscv_npc is 2-cycle, we need to track:
//   - query_sent_q: a query has been sent, waiting for result
//-----------------------------------------------------------------
reg query_sent_q;

always @(posedge clk_i or posedge rst_i)
if (rst_i)
    query_sent_q <= 1'b0;
else if (branch_request_i)
    query_sent_q <= 1'b0;           // Redirect cancels pending query
else if (valid_o && ready_i)
    query_sent_q <= 1'b0;           // Handshake success, start new query next cycle
else if (!query_sent_q)
    query_sent_q <= 1'b1;           // Send query, wait for result

//-----------------------------------------------------------------
// Valid signal
// Result is valid one cycle after query was sent
//-----------------------------------------------------------------
assign valid_o = query_sent_q;

//-----------------------------------------------------------------
// Handshake
//-----------------------------------------------------------------
wire pc_accept_w = valid_o && ready_i;

//-----------------------------------------------------------------
// PC Register Update
//-----------------------------------------------------------------
always @(posedge clk_i or posedge rst_i)
if (rst_i)
    pc_q <= RESET_VECTOR;
else if (branch_request_i)
    pc_q <= branch_pc_i;           // Branch redirect has priority
else if (pc_accept_w)
    pc_q <= next_pc_w;             // Handshake success, update to predicted PC

//-----------------------------------------------------------------
// Outputs
//-----------------------------------------------------------------
wire [31:0] pc_req = rst_i ? RESET_VECTOR : branch_request_i ? branch_pc_i : pc_accept_w ? next_pc_w : pc_q;

assign pc_o          = pc_q;
assign pred_branch_o = next_taken_w;

//-----------------------------------------------------------------
// Branch Predictor (biriscv_npc, assumed 2-cycle latency)
//-----------------------------------------------------------------
biriscv_npc
#(
     .SUPPORT_BRANCH_PREDICTION(SUPPORT_BRANCH_PREDICTION)
    ,.NUM_BTB_ENTRIES(NUM_BTB_ENTRIES)
    ,.NUM_BTB_ENTRIES_W(NUM_BTB_ENTRIES_W)
    ,.NUM_BHT_ENTRIES(NUM_BHT_ENTRIES)
    ,.NUM_BHT_ENTRIES_W(NUM_BHT_ENTRIES_W)
    ,.RAS_ENABLE(RAS_ENABLE)
    ,.GSHARE_ENABLE(GSHARE_ENABLE)
    ,.BHT_ENABLE(BHT_ENABLE)
    ,.NUM_RAS_ENTRIES(NUM_RAS_ENTRIES)
    ,.NUM_RAS_ENTRIES_W(NUM_RAS_ENTRIES_W)
)
u_npc
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.invalidate_i(invalidate_i)

    // Branch feedback
    ,.branch_request_i(branch_request_i)
    ,.branch_is_taken_i(branch_is_taken_i)
    ,.branch_is_not_taken_i(branch_is_not_taken_i)
    ,.branch_source_i(branch_source_i)
    ,.branch_is_call_i(branch_is_call_i)
    ,.branch_is_ret_i(branch_is_ret_i)
    ,.branch_is_jmp_i(branch_is_jmp_i)
    ,.branch_pc_i(branch_pc_i)

    // PC input (from our pc_q)
    ,.pc_f_i(pc_req)
    ,.pc_accept_i(pc_accept_w)

    // Predicted next PC output (2-cycle latency)
    ,.next_pc_f_o_r(next_pc_w)
    ,.next_taken_f_o_r(next_taken_w)
);

endmodule
