#include <bitset>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <random>
#include <array>
#include <algorithm>
#include "Vint_to_float.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

static std::mt19937 gen;
static std::uniform_int_distribution<unsigned int> dist(0, 2 << 12 - 1);

static void progress_one_cycle(VerilatedContext& context, Vint_to_float& testMod, unsigned int& input) {
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 0;

    unsigned int val = dist(gen);
    testMod.in = val;
    input = val;

    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 1;
    testMod.eval();
}

static bool validate(Vint_to_float& testMod, unsigned int input) {
    float output = static_cast<float>(input);

    if (output != *reinterpret_cast<float *>(&testMod.out)) {
        std::cout << "Detected mismatch for conversion of " << input << ": expected '" << output << "' (" << std::hex << *reinterpret_cast<unsigned int *>(&output) << std::dec << "), but got '" << *reinterpret_cast<float *>(&testMod.out) << "' (" << std::hex << testMod.out << std::dec << ")" << std::endl;
        return false;
    } else {
        std::cout << input << " = " << output << std::endl;
    }
    return true;
}

int main(int argc, char **argv) {
    Verilated::mkdir("logs");

    VerilatedContext context;

    context.debug(0);
    context.traceEverOn(true);
    context.commandArgs(argc, argv);

    Vint_to_float testMod(&context, "INT_TO_FLOAT");

    std::random_device rd;
    gen = std::mt19937(rd());

    unsigned int input;

    // testMod.clk = 0;
    // testMod.start = 0;
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 1;
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 0;

    unsigned int val = 0;
    testMod.in = val;
    input = val;

    // testMod.start = 1;
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 1;
    testMod.eval();

    bool failure = false;
    if (!validate(testMod, input)) {
        failure = true;
    } else {
        static const int num_sim_cycles = 1024;
        for (int iter = 0; iter < num_sim_cycles; ++iter) {
            progress_one_cycle(context, testMod, input);
            if (!validate(testMod, input)) {
                failure = true;
                break;
            }
        }
    }

    context.timeInc(1);  // 1 timeprecision period passes...
    // testMod.clk = !testMod.clk;
    testMod.eval();

    testMod.final();

    context.statsPrintSummary();

    return failure ? 1 : 0;
}

