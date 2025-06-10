#include <bitset>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <random>
#include <array>
#include <algorithm>
#include "Vmatvec_wrapper.h"
#include "Vmatvec_wrapper_matvec_wrapper.h"
#include <verilated.h>
#include <verilated_vcd_c.h>

static std::mt19937 gen;
static std::uniform_int_distribution<unsigned int> dist(0, 10);
static std::uniform_real_distribution<float> wdist(-1, 1);

static void progress_one_cycle(VerilatedContext& context, Vmatvec_wrapper& testMod, std::vector<unsigned int>& input, std::vector<std::vector<float>>& weights, bool acc_rst) {
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 0;
    for (int i = 0; i < testMod.matvec_wrapper->N; ++i) {
        unsigned int val = dist(gen);
        testMod.in[i] = val;
        input[i] = val;
    }

    for (int i = 0; i < testMod.matvec_wrapper->M; ++i) {
        for (int j = 0; j < testMod.matvec_wrapper->N; ++j) {
            float val = wdist(gen);
            testMod.weights[i][j] = *reinterpret_cast<unsigned int *>(&val);
            weights[i][j] = val;
        }
    }

    testMod.do_acc = !acc_rst;

    testMod.eval();
    context.timeInc(1);
    testMod.clk = 1;
    testMod.eval();
}

static bool validate(Vmatvec_wrapper& testMod, std::vector<unsigned int>& input, std::vector<std::vector<float>>& weights, std::vector<float>& output, bool acc_rst) {

    for (int i = 0; i < testMod.matvec_wrapper->M; ++i) {
        std::vector<float> sum(input.size(), 0);
        for (int j = 0; j < input.size(); ++j) {
            if (j < testMod.matvec_wrapper->N) {
                sum[j] = input[j] * weights[i][j];
            } else {
                sum[j] = 0;
            }
        }

        for (int l = sum.size(); l > 1; l /= 2) {
            for (int j = 0; j < l; j += 2) {
                // std::cout << sum[j] << " (" << std::hex << *reinterpret_cast<int *>(&sum[j]) << ") + " << sum[j + 1] << " (" << *reinterpret_cast<int *>(&sum[j + 1]) << ") = ";
                sum[j / 2] = sum[j] + sum[j + 1];
                // std::cout << sum[j / 2] << " (" << *reinterpret_cast<int *>(&sum[j / 2]) << ")" << std::dec << std::endl;
            }
            // std::cout << std::endl;
        }

        if (acc_rst) {
            output[i] = 0;
        }
        // std::cout << "output[" << i << "] = " << output[i] << ", sum = " << sum[0] << std::endl << std::endl;
        output[i] += sum[0];
    }

    for (int i = 0; i < testMod.matvec_wrapper->M; ++i) {
        if ((output[i] > 0 && (*reinterpret_cast<float *>(&testMod.out[i]) < .999 * output[i] || *reinterpret_cast<float *>(&testMod.out[i]) > 1.001 * output[i]))
            ||
            (output[i] < 0 && (*reinterpret_cast<float *>(&testMod.out[i]) > .999 * output[i] || *reinterpret_cast<float *>(&testMod.out[i]) < 1.001 * output[i]))) {
            std::cerr << "Detected mismatch at index " << i << ": expected '"
                << output[i] << "' (" << std::hex
                << *reinterpret_cast<int *>(&output[i]) << "), but got '"
                << *reinterpret_cast<float *>(&testMod.out[i]) << "' ("
                << testMod.out[i] << ")" << std::dec << std::endl;
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

    Vmatvec_wrapper testMod(&context, "MATVEC");

    std::random_device rd;
    gen = std::mt19937(rd());

    int input_buff_len = pow(2, ceil(log2(testMod.matvec_wrapper->N)));
    std::vector<unsigned int> input(input_buff_len, 0);
    std::vector<std::vector<float>> weights(testMod.matvec_wrapper->M);

    for (int i = 0; i < testMod.matvec_wrapper->M; ++i) {
        weights[i] = std::vector<float>(testMod.matvec_wrapper->N);
    }

    testMod.clk = 0;
    // testMod.start = 0;
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 1;
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 0;
    for (int i = 0; i < testMod.matvec_wrapper->N; ++i) {
        unsigned int val = dist(gen);
        testMod.in[i] = val;
        input[i] = val;
    }

    for (int i = 0; i < testMod.matvec_wrapper->M; ++i) {
        for (int j = 0; j < testMod.matvec_wrapper->N; ++j) {
            float val = wdist(gen);
            testMod.weights[i][j] = *reinterpret_cast<unsigned int *>(&val);
            weights[i][j] = val;
        }
    }

    // testMod.start = 1;
    testMod.eval();
    context.timeInc(1);
    testMod.clk = 1;
    testMod.eval();

    static const int num_sim_cycles = 1024;
    bool failure = false;
    std::vector<float> output(testMod.matvec_wrapper->M);
    for (int iter = 0; iter < num_sim_cycles; ++iter) {
        bool acc_rst = iter % 4 == 0;
        progress_one_cycle(context, testMod, input, weights, acc_rst);
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

