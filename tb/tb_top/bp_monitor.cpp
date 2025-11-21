#include "bp_monitor.h"
#include "Vriscv_top.h"
#include "Vriscv_top___024root.h"
#include "Vriscv_top_riscv_core__N200_NB9.h"
#include "Vriscv_top_riscv_top.h"

// Constructor
BPMonitor::BPMonitor(Vriscv_top *dut)
    : m_dut(dut), m_prev_pc(0), m_prev_pc_valid(false), m_cycle_count(0) {
  m_stats.reset();

  // Open trace file
  m_trace_file.open("trace.txt");
}

// Destructor
BPMonitor::~BPMonitor() {
  if (m_trace_file.is_open()) {
    m_trace_file.close();
  }
}

// Main monitoring function
void BPMonitor::monitor() {
  m_cycle_count++;

  // Access the NPC signals through the DUT hierarchy
  auto core = m_dut->rootp->v->u_core;

  // Get all signals for trace

  bool branch_request_i = core->u_frontend__DOT__u_npc__DOT__branch_request_i;
  bool branch_is_taken_i = core->u_frontend__DOT__u_npc__DOT__branch_is_taken_i;
  bool branch_is_not_taken_i =
      core->u_frontend__DOT__u_npc__DOT__branch_is_not_taken_i;

  bool branch_is_call_i = core->u_frontend__DOT__u_npc__DOT__branch_is_call_i;
  bool branch_is_ret_i = core->u_frontend__DOT__u_npc__DOT__branch_is_ret_i;
  bool branch_is_jmp_i = core->u_frontend__DOT__u_npc__DOT__branch_is_jmp_i;

  uint32_t branch_pc = core->u_frontend__DOT__u_npc__DOT__branch_source_i;

  bool taken_no_taken = branch_is_taken_i || branch_is_not_taken_i;

  // Branch type statistics
  // uint64_t taken_branches;           // Taken branches
  // uint64_t not_taken_branches;       // Not taken branches
  // uint64_t calls;                    // Call instructions
  // uint64_t returns;                  // Return instructions
  // uint64_t jumps;                    // Jump instructions

  // Write trace when there is a prediction or branch resolution
  // if (pc_accept && m_trace_file.is_open()) {
  if (taken_no_taken && m_trace_file.is_open()) {
    m_trace_file << "0x" << std::hex << std::setw(8) << std::setfill('0')
                 << branch_pc << "   " << (int)branch_is_taken_i << " "
                 << (int)branch_is_not_taken_i << " " << (int)branch_is_call_i
                 << " " << (int)branch_is_ret_i << " " << (int)branch_is_jmp_i
                 << "     " << (int)branch_request_i

                 << std::endl;
  }

  if (taken_no_taken && !branch_request_i) {
    m_stats.total_predictions++;
    // Count as correct prediction (will be corrected if misprediction happens)
    m_stats.direction_correct++;
    m_stats.overall_correct++;
    m_stats.total_branches++;
    m_stats.target_correct++;

    // Branch type statistics
    if (branch_is_taken_i) {
      m_stats.taken_branches++;
    } else if (branch_is_not_taken_i) {
      m_stats.not_taken_branches++;
    }
    if (branch_is_call_i) {
      m_stats.calls++;
    }
    if (branch_is_ret_i) {
      m_stats.returns++;
    }
    if (branch_is_jmp_i) {
      m_stats.jumps++;
    }
  }

  if (branch_request_i && taken_no_taken) {

    // Correct the statistics - remove one correct, add one incorrect
    if (m_stats.direction_correct > 0) {
      m_stats.direction_correct--;
      m_stats.direction_incorrect++;
    }
    if (m_stats.overall_correct > 0) {
      m_stats.overall_correct--;
      m_stats.overall_incorrect++;
    }
    if (m_stats.target_correct > 0) {
      m_stats.target_correct--;
      m_stats.target_incorrect++;
    }
  }
}
