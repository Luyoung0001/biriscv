//-----------------------------------------------------------------
//                         biRISC-V CPU
//                            V0.8.1
//                     Ultra-Embedded.com
//                     Copyright 2019-2020
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------
// Modified: PC now comes from upstream next_pc_generator module
// Architecture: next_pc_generator --> Fetch --> icache
//-----------------------------------------------------------------

module biriscv_fetch
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_MMU      = 1
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           fetch_accept_i
    ,input           icache_accept_i
    ,input           icache_valid_i
    ,input           icache_error_i
    ,input  [ 63:0]  icache_inst_i
    ,input           icache_page_fault_i
    ,input           fetch_invalidate_i

    // Branch redirect (still needed to drop icache responses)
    ,input           branch_request_i
    ,input  [ 31:0]  branch_pc_i
    ,input  [  1:0]  branch_priv_i

    // From next_pc_generator (upstream)
    ,input  [ 31:0]  pc_i              // PC to fetch
    ,input           pc_valid_i        // PC is valid
    ,input  [  1:0]  pred_branch_i     // Branch prediction info

    // Outputs
    ,output          fetch_valid_o
    ,output [ 63:0]  fetch_instr_o
    ,output [  1:0]  fetch_pred_branch_o
    ,output          fetch_fault_fetch_o
    ,output          fetch_fault_page_o
    ,output [ 31:0]  fetch_pc_o
    ,output          icache_rd_o
    ,output          icache_flush_o
    ,output          icache_invalidate_o
    ,output [ 31:0]  icache_pc_o
    ,output [  1:0]  icache_priv_o

    // To next_pc_generator (upstream) - handshake
    ,output          pc_ready_o        // Ready to accept PC
);



//-------------------------------------------------------------
// Registers / Wires
//-------------------------------------------------------------
reg         active_q;

wire        icache_busy_w;
wire        stall_w       = !fetch_accept_i || icache_busy_w || !icache_accept_i;

//-------------------------------------------------------------
// Buffered branch (for dropping responses)
//-------------------------------------------------------------
reg         branch_q;
reg [1:0]   branch_priv_q;

wire        branch_w;
wire [1:0]  branch_priv_w;

generate
if (SUPPORT_MMU)
begin
    assign branch_w      = branch_q;
    assign branch_priv_w = branch_priv_q;

    always @ (posedge clk_i or posedge rst_i)
    if (rst_i)
    begin
        branch_q       <= 1'b0;
        branch_priv_q  <= `PRIV_MACHINE;
    end
    else if (branch_request_i)
    begin
        branch_q       <= 1'b1;
        branch_priv_q  <= branch_priv_i;
    end
    else if (icache_rd_o && icache_accept_i)
    begin
        branch_q       <= 1'b0;
    end
end
else
begin
    assign branch_w      = branch_q || branch_request_i;
    assign branch_priv_w = `PRIV_MACHINE; // don't care

    always @ (posedge clk_i or posedge rst_i)
    if (rst_i)
    begin
        branch_q       <= 1'b0;
    end
    else if (branch_request_i && (icache_busy_w || !active_q))
    begin
        branch_q       <= branch_w;
    end
    else if (~icache_busy_w)
    begin
        branch_q       <= 1'b0;
    end

end
endgenerate

//-------------------------------------------------------------
// Active flag - activated when we receive first valid PC
//-------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    active_q    <= 1'b0;
else if (pc_valid_i)
    active_q    <= 1'b1;

//-------------------------------------------------------------
// Stall flag
//-------------------------------------------------------------
reg stall_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    stall_q    <= 1'b0;
else
    stall_q    <= stall_w;

//-------------------------------------------------------------
// Request tracking
//-------------------------------------------------------------
reg icache_fetch_q;
reg icache_invalidate_q;

// ICACHE fetch tracking
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    icache_fetch_q <= 1'b0;
else if (icache_rd_o && icache_accept_i)
    icache_fetch_q <= 1'b1;
else if (icache_valid_i)
    icache_fetch_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    icache_invalidate_q <= 1'b0;
else if (icache_invalidate_o && !icache_accept_i)
    icache_invalidate_q <= 1'b1;
else
    icache_invalidate_q <= 1'b0;

//-------------------------------------------------------------
// PC - now comes from next_pc_generator
//-------------------------------------------------------------
reg [31:0]  pc_d_q;       // PC of last issued request (for response)
reg [1:0]   pred_d_q;     // Prediction info of last request

wire [31:0] icache_pc_w;
wire [1:0]  icache_priv_w;
wire        fetch_resp_drop_w;

generate
if (SUPPORT_MMU)
begin
    reg [1:0] priv_f_q;
    reg       branch_d_q;

    always @ (posedge clk_i or posedge rst_i)
    if (rst_i)
        priv_f_q  <= `PRIV_MACHINE;
    else if (branch_request_i)
        priv_f_q  <= branch_priv_i;

    always @ (posedge clk_i or posedge rst_i)
    if (rst_i)
        branch_d_q  <= 1'b0;
    else if (branch_request_i)
        branch_d_q  <= 1'b1;
    else if (icache_rd_o && icache_accept_i)
        branch_d_q  <= 1'b0;

    // Use PC from next_pc_generator directly
    assign icache_pc_w       = pc_i;
    assign icache_priv_w     = priv_f_q;
    assign fetch_resp_drop_w = branch_w | branch_d_q;
end
else
begin
    // Use PC from next_pc_generator directly
    assign icache_pc_w       = pc_i;
    assign icache_priv_w     = `PRIV_MACHINE; // Don't care
    assign fetch_resp_drop_w = branch_w;
end
endgenerate

// Record PC of issued request (for response matching)
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    pc_d_q <= 32'b0;
else if (icache_rd_o && icache_accept_i)
    pc_d_q <= icache_pc_w;

// Record prediction info
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    pred_d_q <= 2'b0;
else if (icache_rd_o && icache_accept_i)
    pred_d_q <= pred_branch_i;
else if (icache_valid_i)
    pred_d_q <= 2'b0;

//-------------------------------------------------------------
// Outputs
//-------------------------------------------------------------
// Issue icache request when: active, downstream ready, not busy, and upstream has valid PC
assign icache_rd_o         = active_q & fetch_accept_i & !icache_busy_w & pc_valid_i;
assign icache_pc_o         = {icache_pc_w[31:3],3'b0};
assign icache_priv_o       = icache_priv_w;
assign icache_flush_o      = fetch_invalidate_i | icache_invalidate_q;
assign icache_invalidate_o = 1'b0;

assign icache_busy_w       =  icache_fetch_q && !icache_valid_i;

// Ready signal to upstream next_pc_generator
// We accept PC when we successfully issue an icache request
assign pc_ready_o          = icache_rd_o & icache_accept_i;

//-------------------------------------------------------------
// Response Buffer
//-------------------------------------------------------------
reg [99:0]  skid_buffer_q;
reg         skid_valid_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    skid_buffer_q  <= 100'b0;
    skid_valid_q   <= 1'b0;
end
// Instruction output back-pressured - hold in skid buffer
else if (fetch_valid_o && !fetch_accept_i)
begin
    skid_valid_q  <= 1'b1;
    skid_buffer_q <= {fetch_fault_page_o, fetch_fault_fetch_o, fetch_pred_branch_o, fetch_pc_o, fetch_instr_o};
end
else
begin
    skid_valid_q  <= 1'b0;
    skid_buffer_q <= 100'b0;
end

assign fetch_valid_o       = (icache_valid_i || skid_valid_q) & !fetch_resp_drop_w;
assign fetch_pc_o          = skid_valid_q ? skid_buffer_q[95:64] : {pc_d_q[31:3],3'b0};
assign fetch_instr_o       = skid_valid_q ? skid_buffer_q[63:0]  : icache_inst_i;
assign fetch_pred_branch_o = skid_valid_q ? skid_buffer_q[97:96] : pred_d_q;

// Faults
assign fetch_fault_fetch_o = skid_valid_q ? skid_buffer_q[98] : icache_error_i;
assign fetch_fault_page_o  = skid_valid_q ? skid_buffer_q[99] : icache_page_fault_i;



endmodule
