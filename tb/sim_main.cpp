#include <bitset>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <random>
#include <array>
#include <algorithm>
#include "Vmatvec.h"
#include "Vmatvec_matvec.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

static std::mt19937 gen;
static std::uniform_int_distribution<unsigned int> dist(0, 10);
static std::uniform_int_distribution<unsigned int> wdist(0, 10);

static void progress_one_cycle(VerilatedContext& context, Vmatvec& testMod, std::vector<unsigned int>& input, std::vector<std::vector<unsigned int>>& weights, std::vector<unsigned int>& output, bool acc_rst) {
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 0;
    for (int i = 0; i < testMod.matvec->N; ++i) {
        unsigned int val = dist(gen);
        testMod.in[i] = val;
        input[i] = val;
    }

    for (int i = 0; i < testMod.matvec->N; ++i) {
        for (int j = 0; j < testMod.matvec->M; ++j) {
            unsigned int val = wdist(gen);
            testMod.weights[i][j] = val;
            weights[i][j] = val;
        }
    }

    testMod.acc_rst = acc_rst;

    testMod.eval();
    context.timeInc(1);
    testMod.clk = 1;
    testMod.eval();
}

static bool validate(Vmatvec& testMod, std::vector<unsigned int>& input, std::vector<std::vector<unsigned int>>& weights, std::vector<unsigned int>& output, bool acc_rst) {
    if (acc_rst) {
        output.assign(output.size(), 0);
    }

    for (int i = 0; i < testMod.matvec->M; ++i) {
        for (int j = 0; j < testMod.matvec->N; ++j) {
            output[i] += input[j] * weights[j][i];
        }
    }

    for (int i = 0; i < testMod.matvec->M; ++i) {
        if (output[i] != static_cast<unsigned int>(testMod.out[i])) {
            std::cout << "Detected mismatch at index " << i << ": expected '" << output[i] << "', but got '" << testMod.out[i] << "'" << std::endl;
            return false;
        }
    }
    return true;
}

int main(int argc, char **argv) {
    Verilated::mkdir("logs");

    VerilatedContext context;

    context.debug(0);
    context.traceEverOn(true);
    context.commandArgs(argc, argv);

    Vmatvec testMod(&context, "MATVEC");

    std::random_device rd;
    gen = std::mt19937(rd());
    dist = std::uniform_int_distribution<unsigned int>(0, 10);
    wdist = std::uniform_int_distribution<unsigned int>(0, 10);

    std::vector<unsigned int> input(testMod.matvec->N);
    std::vector<std::vector<unsigned int>> weights(testMod.matvec->N);
    std::vector<unsigned int> output(testMod.matvec->M);

    for (int i = 0; i < testMod.matvec->N; ++i) {
        weights[i] = std::vector<unsigned int>(testMod.matvec->M);
    }

    testMod.clk = 0;
    // testMod.start = 0;
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 1;
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 0;
    for (int i = 0; i < testMod.matvec->N; ++i) {
        unsigned int val = dist(gen);
        testMod.in[i] = val;
        input[i] = val;
    }

    for (int i = 0; i < testMod.matvec->N; ++i) {
        for (int j = 0; j < testMod.matvec->M; ++j) {
            unsigned int val = wdist(gen);
            testMod.weights[i][j] = val;
            weights[i][j] = val;
        }
    }

    // testMod.start = 1;
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 1;
    testMod.eval();

    static const int num_sim_cycles = 16;
    bool failure = false;
    for (int iter = 0; iter < num_sim_cycles; ++iter) {
        bool acc_rst = iter % 4 == 0;
        progress_one_cycle(context, testMod, input, weights, output, acc_rst);
        if (!validate(testMod, input, weights, output, acc_rst)) {
            failure = true;
            break;
        }
    }

    context.timeInc(1);  // 1 timeprecision period passes...
    testMod.clk = !testMod.clk;
    testMod.eval();

    testMod.final();

    context.statsPrintSummary();

    return failure ? 1 : 0;
}

