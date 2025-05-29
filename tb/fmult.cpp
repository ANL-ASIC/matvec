#include <bitset>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <random>
#include <array>
#include <algorithm>
#include "Vint_fp_mult.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

static std::mt19937 gen;
static std::uniform_int_distribution<unsigned int> dist(0, 10);
static std::uniform_real_distribution<float> wdist(-1, 1);

static void progress_one_cycle(VerilatedContext& context, Vint_fp_mult& testMod, unsigned int& input, float& weight) {
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 0;

    unsigned int val = dist(gen);
    testMod.a = val;
    input = val;

    float fval = wdist(gen);
    testMod.b = *reinterpret_cast<unsigned int *>(&fval);
    weight = fval;

    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 1;
    testMod.eval();
}

static bool validate(Vint_fp_mult& testMod, unsigned int input, float weight) {
    float output = static_cast<float>(input) * weight;

    if (output != *reinterpret_cast<float *>(&testMod.c)) {
        std::cout << "Detected mismatch for " << input << " * " << weight << ": expected '" << output << "' (" << std::hex << *reinterpret_cast<unsigned int *>(&output) << std::dec << "), but got '" << *reinterpret_cast<float *>(&testMod.c) << "' (" << std::hex << testMod.c << std::dec << ")" << std::endl;
        return false;
    } else {
        std::cout << input << " * " << weight << " = " << output << std::endl;
    }
    return true;
}

int main(int argc, char **argv) {
    Verilated::mkdir("logs");

    VerilatedContext context;

    context.debug(0);
    context.traceEverOn(true);
    context.commandArgs(argc, argv);

    Vint_fp_mult testMod(&context, "MATVEC");

    std::random_device rd;
    gen = std::mt19937(rd());

    unsigned int input;
    float weight;

    // testMod.clk = 0;
    // testMod.start = 0;
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 1;
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 0;

    unsigned int val = dist(gen);
    testMod.a = val;
    input = val;

    float fval = wdist(gen);
    testMod.b = *reinterpret_cast<unsigned int *>(&fval);
    weight = fval;

    // testMod.start = 1;
    testMod.eval();
    context.timeInc(1);
    // testMod.clk = 1;
    testMod.eval();

    static const int num_sim_cycles = 16;
    bool failure = false;
    for (int iter = 0; iter < num_sim_cycles; ++iter) {
        progress_one_cycle(context, testMod, input, weight);
        if (!validate(testMod, input, weight)) {
            failure = true;
            break;
        }
    }

    context.timeInc(1);  // 1 timeprecision period passes...
    // testMod.clk = !testMod.clk;
    testMod.eval();

    testMod.final();

    context.statsPrintSummary();

    return failure ? 1 : 0;
}

