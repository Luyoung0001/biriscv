#ifndef BP_MONITOR_H
#define BP_MONITOR_H

#include <systemc.h>
#include <cstdint>
#include <iostream>
#include <iomanip>
#include <cstring>
#include <fstream>
#include "Vriscv_top.h"
#include "verilated.h"

// Branch predictor performance statistics structure
struct BranchPredictorStats {
    // Overall statistics
    uint64_t total_branches;           // Total resolved branches
    uint64_t total_predictions;        // Total predictions made

    // Direction prediction statistics
    uint64_t direction_correct;        // Direction prediction correct
    uint64_t direction_incorrect;      // Direction prediction incorrect

    // Target address prediction statistics
    uint64_t target_correct;           // Target address prediction correct
    uint64_t target_incorrect;         // Target address prediction incorrect

    // Overall prediction statistics (both direction and target correct)
    uint64_t overall_correct;          // Overall prediction correct
    uint64_t overall_incorrect;        // Overall prediction incorrect

    // Branch type statistics
    uint64_t taken_branches;           // Taken branches
    uint64_t not_taken_branches;       // Not taken branches
    uint64_t calls;                    // Call instructions
    uint64_t returns;                  // Return instructions
    uint64_t jumps;                    // Jump instructions

    // Calculate statistics ratios
    double get_direction_accuracy() const {
        uint64_t total = direction_correct + direction_incorrect;
        return total > 0 ? (double)direction_correct / total * 100.0 : 0.0;
    }

    double get_target_accuracy() const {
        uint64_t total = target_correct + target_incorrect;
        return total > 0 ? (double)target_correct / total * 100.0 : 0.0;
    }

    double get_overall_accuracy() const {
        uint64_t total = overall_correct + overall_incorrect;
        return total > 0 ? (double)overall_correct / total * 100.0 : 0.0;
    }

    void reset() {
        memset(this, 0, sizeof(BranchPredictorStats));
    }

    void print() const {
        std::cout << "\n========================================" << std::endl;
        std::cout << "   Branch Predictor Statistics" << std::endl;
        std::cout << "========================================" << std::endl;

        std::cout << "\n--- Overall Statistics ---" << std::endl;
        std::cout << "Total Branches:      " << total_branches << std::endl;
        std::cout << "Total Predictions:   " << total_predictions << std::endl;

        std::cout << "\n--- Direction Prediction ---" << std::endl;
        std::cout << "Correct:             " << direction_correct << std::endl;
        std::cout << "Incorrect:           " << direction_incorrect << std::endl;
        std::cout << "Accuracy:            " << std::fixed << std::setprecision(2)
                  << get_direction_accuracy() << "%" << std::endl;

        std::cout << "\n--- Target Address Prediction ---" << std::endl;
        std::cout << "Correct:             " << target_correct << std::endl;
        std::cout << "Incorrect:           " << target_incorrect << std::endl;
        std::cout << "Accuracy:            " << std::fixed << std::setprecision(2)
                  << get_target_accuracy() << "%" << std::endl;

        std::cout << "\n--- Overall Prediction (Direction + Target) ---" << std::endl;
        std::cout << "Correct:             " << overall_correct << std::endl;
        std::cout << "Incorrect:           " << overall_incorrect << std::endl;
        std::cout << "Accuracy:            " << std::fixed << std::setprecision(2)
                  << get_overall_accuracy() << "%" << std::endl;

        std::cout << "\n--- Branch Type Distribution ---" << std::endl;
        std::cout << "Taken:               " << taken_branches << std::endl;
        std::cout << "Not Taken:           " << not_taken_branches << std::endl;
        std::cout << "Calls:               " << calls << std::endl;
        std::cout << "Returns:             " << returns << std::endl;
        std::cout << "Jumps:               " << jumps << std::endl;

        std::cout << "========================================\n" << std::endl;
    }
};

// Branch predictor monitor class
class BPMonitor {
private:
    Vriscv_top* m_dut;                 // Verilator DUT instance
    BranchPredictorStats m_stats;      // Statistics data

    // Track previous PC to detect execution flow
    uint32_t m_prev_pc;
    bool m_prev_pc_valid;
    uint64_t m_cycle_count;

    // Trace file for detailed signal logging
    std::ofstream m_trace_file;

    // Helper function to process branch resolution (misprediction)
    void process_branch_misprediction(uint32_t branch_pc, bool branch_taken,
                                      bool branch_ntaken, uint32_t branch_target,
                                      bool branch_call, bool branch_ret, bool branch_jmp);

    // Helper function to check if prediction was correct
    void check_prediction_correctness(uint32_t current_pc);

public:
    BPMonitor(Vriscv_top* dut);
    ~BPMonitor();

    // Main monitoring function, called every clock cycle
    void monitor();

    // Statistics interface
    const BranchPredictorStats& get_stats() const { return m_stats; }
    void reset_stats() { m_stats.reset(); }
    void print_stats() const { m_stats.print(); }
};

#endif // BP_MONITOR_H
