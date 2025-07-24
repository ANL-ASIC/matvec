import cocotb, math, random
import numpy as np
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.binary import BinaryValue
from arbitrary_float import AFloat, AFloatConfig, AFloatArray
import random

int_to_fp32 = {
         -16: "11000001100000000000000000000000",
         -15: "11000001011100000000000000000000",
         -14: "11000001011000000000000000000000",
         -13: "11000001010100000000000000000000",
         -12: "11000001010000000000000000000000",
         -11: "11000001001100000000000000000000",
         -10: "11000001001000000000000000000000",
          -9: "11000001000100000000000000000000",
          -8: "11000001000000000000000000000000",
          -7: "11000000111000000000000000000000",
          -6: "11000000110000000000000000000000",
          -5: "11000000101000000000000000000000",
          -4: "11000000100000000000000000000000",
          -3: "11000000010000000000000000000000",
          -2: "11000000000000000000000000000000",
          -1: "10111111100000000000000000000000",
          .5: "00111111000000000000000000000000",
           0: "00000000000000000000000000000000",
           1: "00111111100000000000000000000000",
           2: "01000000000000000000000000000000",
           3: "01000000010000000000000000000000",
           4: "01000000100000000000000000000000",
           5: "01000000101000000000000000000000",
           6: "01000000110000000000000000000000",
           7: "01000000111000000000000000000000",
           8: "01000001000000000000000000000000",
           9: "01000001000100000000000000000000",
          10: "01000001001000000000000000000000",
          11: "01000001001100000000000000000000",
          12: "01000001010000000000000000000000",
          13: "01000001010100000000000000000000",
          14: "01000001011000000000000000000000",
          15: "01000001011100000000000000000000",
          16: "01000001100000000000000000000000",
          .25: "00111110100000000000000000000000",
          0.3333329856395721435546875: "00111110101010101010101010011111"
        }


class SimStatus:
    do_sim = True


def get_float_np_type(dut):
    return np.float16 if (dut.EWIDTH.value + dut.SIGWIDTH.value + 1) <= 16 else np.float32


async def generate_clock(dut, sim_status):
    while True:
        dut.clk.value = 0
        await Timer(1, units="ns")
        dut.clk.value = 1
        await Timer(1, units="ns")
    return False


async def invalid_signal_watchdog(dut, sim_status):
    while sim_status.do_sim:
        await FallingEdge(dut.clk)
        assert(dut.SRO_invalid == 0)
        assert(dut.dv_invalid == 0)
    return False


def init(dut):
    dut.clk.value = 0
    dut.reset.value = 0
    dut.SRO.value = 0
    dut.dv.value = 0
    dut.write_enable.value = 0
    dut.write_addr.value = 0
    return SimStatus()


def get_exp_and_sig(val):
    if abs(val) == 0.0:
        return (0, 0)

    sig = abs(val)
    exp = 0
    while sig >= 2:
        sig /= 2
        exp += 1

    while sig < 1:
        sig *= 2
        exp -= 1
    return (exp, sig)


def signal_to_np_array_2D(signal, len_D1, len_D2, width):
    arr = []
    for i in range(len_D1):
        arr.append([])
        for j in range(len_D2):
            start = i * len_D2 * width + (len_D2 - j - 1) * width
            arr[-1].append(signal[start:start + width])
    return arr


def gen_random_frame(dut):
    rng = np.random.default_rng(random.randint(0, 2 ** 32 - 1)) # Derive random state from python's random module to make runs reproducible
    return rng.uniform(low=0, high=(2 ** (dut.pixel_data_width.value - 1) - 1), size=(dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value)).astype(np.uint16)


def gen_all_ones_frame(dut):
    frame = np.ones((dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value), dtype=np.uint16)
    return frame


def gen_random_weights(dut):
    dut._log.debug('Generating random weights')
    dtype = get_float_np_type(dut)
    rng = np.random.default_rng(random.randint(0, 2 ** 32 - 1)) # Derive random state from python's random module to make runs reproducible
    weights = rng.uniform(low=-1.0, high=1.0, size=(dut.K.value, dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value)).astype(dtype)
    max_weights_sum = 1 / ((dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value) // 2)
    for k in range(dut.K.value):
        weight_sum = weights[k].sum()
        if weight_sum > max_weights_sum:
            weights[k] = weights[k] * (max_weights_sum / weight_sum)
    weights = np.where(weights < 1.0 * 2 ** (1 - (2 ** (dut.EWIDTH.value - 1) - 1)), 0, weights)
    weights = AFloatArray(weights).as_config(AFloatConfig(exponent_bits = dut.WEIGHT_EWIDTH.value, mantissa_bits = dut.WEIGHT_SIGWIDTH.value, bias = dut.WEIGHT_BIAS.value, nan_inf_support = False, subnormal_support=False))

    dut._log.debug('Done generating weights')

    return weights


def gen_fixed_weights(dut):
    dut._log.debug('Generating fixed weights')
    dtype = get_float_np_type(dut)
    weights = np.zeros((dut.K.value, dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value), dtype=dtype)
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            weights[i][j] = dtype((1 if j % 2 == 0 else -2**-6) / (j / 2 + 1))
    weights = AFloatArray(weights).as_config(AFloatConfig(exponent_bits = dut.WEIGHT_EWIDTH.value, mantissa_bits = dut.WEIGHT_SIGWIDTH.value, bias = dut.WEIGHT_BIAS.value, nan_inf_support = False, subnormal_support=False))

    dut._log.debug('Done generating weights')

    return weights


def print_matvec(dut, weights, frame, expected_vals):
    weights = weights.to_numpy()
    expected_vals = expected_vals.to_numpy()
    for i in range(len(weights)):
        if i == 0:
            row = '['
            for val in frame:
                row += f' {val}'
            row += ' ] X '
        else:
            row = ' '
            for j in range(len(frame)):
                row += '  '
            row += '     '

        row += '['
        for val in weights[i]:
            row += f' {val}'
        row += ' ]'

        row += ' = ' if i == 0 else '   '

        if i == 0:
            row += '['
            for val in expected_vals:
                row += f' {val}'
            row += ' ]'

        print(row)


async def write_weights(dut, weights):
    dut._log.debug('Writing weights...')

    # write weights to SRAM
    dut.write_enable.value = 1
    for addr in range(dut.number_of_rows_per_frame.value):
        dut._log.debug(f'Writing row {addr}...')
        dut.write_addr.value = addr

        # print("write_data is {} by {} elements".format(len(dut.write_data) / len(dut.write_data[0]), len(dut.write_data[0]) / len(dut.write_data[0][0])))
        write_data = ''
        for i in range(dut.K.value):
            for j in range(dut.number_of_columns_per_frame.value):
                # We have to write the words in backwards order because the least significant work (index 0 of the array) is the end of the bit string
                write_data += weights[i][dut.number_of_columns_per_frame.value * addr + (dut.number_of_columns_per_frame.value - j - 1)].binstr()
        # print(f"Writing weights: {write_data}")
        dut.write_data.value = BinaryValue(write_data)

        await RisingEdge(dut.clk)

    dut.write_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.K.value * (1 + dut.WEIGHT_EWIDTH.value + dut.WEIGHT_SIGWIDTH.value)) + 'b'))
    dut.write_enable.value = 0
    dut._log.debug('Weights written...')


async def write_frame(dut, frame, weights, always_valid = True, is_pipelined = False):
    # set full frame
    i = 0
    while i < dut.number_of_rows_per_frame.value:
        set_dv_high = always_valid or random.randint(0, 1) == 1
        row = None
        weights_row = None
        if set_dv_high:
            dut.dv.value = 1
            binstr = ''

            # set full row
            row = frame[dut.number_of_columns_per_frame.value * i:dut.number_of_columns_per_frame.value * (i + 1)]
            for pixel in np.flip(row):
                binstr += format(pixel, '0' + str(dut.pixel_data_width.value) + 'b')
            dut.pixel_data.value = BinaryValue(binstr)
            await Timer(0.5, units="ns")
            weights_row = weights[0:,dut.number_of_columns_per_frame.value * i:dut.number_of_columns_per_frame.value * (i + 1)]
            i += 1

            if i == dut.number_of_rows_per_frame and is_pipelined:
                dut.SRO.value = 1
        else:
            dut.dv.value = 0
            dut.pixel_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.pixel_data_width.value) + 'b'))

        await RisingEdge(dut.clk)
        dut.SRO.value = 0

        if set_dv_high:
            if i == 1:
                await cocotb.start(validate_multiplies(dut, row, weights_row))
                await cocotb.start(validate_tree(dut))

    dut.pixel_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.pixel_data_width.value) + 'b'))
    dut.dv.value = 0


async def validate_multiplies(dut, row, weights):
    dut._log.debug(f'In validate_multiplies')
    prod_conf = AFloatConfig(dut.PROD_EWIDTH.value, dut.PROD_SIGWIDTH.value, nan_inf_support=False, subnormal_support=False)
    width = dut.PROD_EWIDTH.value + dut.PROD_SIGWIDTH.value + 1
    result_binstrs = signal_to_np_array_2D(dut.mac.mult_intermediates.value.binstr, dut.K.value, dut.number_of_columns_per_frame.value, width)
    row_af = AFloatArray(row).as_config(config=AFloatConfig.ieee64())

    for i in range(dut.K.value):
        dut._log.debug(f'Validating component {i}')
        expected_vals = weights[i].mul(row_af, result_config=prod_conf)
        for j in range(dut.number_of_columns_per_frame.value):
            result_binstr = result_binstrs[i][j]
            result = AFloat.from_literal(int(result_binstr, 2), prod_conf).as_float()
            expected = expected_vals[j]
            expected_binstr = expected.binstr()
            expected = expected.as_float()
            assert expected == result, f'{i}, {j}: {int(row[j])} * {weights[i][j].as_float()}; result={result} ({result_binstr}) expected={expected} ({expected_binstr})'


async def validate_tree(dut):
    dut._log.debug(f'In validate_tree')
    prod_conf = AFloatConfig(exponent_bits = dut.PROD_EWIDTH.value, mantissa_bits = dut.PROD_SIGWIDTH.value, nan_inf_support=False, subnormal_support=False)
    res_conf = AFloatConfig(exponent_bits = dut.EWIDTH.value, mantissa_bits = dut.SIGWIDTH.value, nan_inf_support=False, subnormal_support=False)
    num_operands = dut.number_of_columns_per_frame.value
    level = int(math.log2(num_operands)) - 1
    await FallingEdge(dut.clk)
    while num_operands > 1:
        dut._log.debug(f'Validating level {level}')
        for i in range(dut.K.value):
            for j in range(int(num_operands / 2)):
                signal_id_base = f'accumulators[{i}].acc.acc_lvls[{level}].acc_rows[{j}].' + ('first_lvl' if level == int(math.log2(dut.number_of_columns_per_frame.value)) - 1 else 'lvls') + '.fpadd'
                X = AFloat.from_literal(int(dut.mac._id(signal_id_base + '.X', extended=False).value.binstr, 2), prod_conf)
                Y = AFloat.from_literal(int(dut.mac._id(signal_id_base + '.Y', extended=False).value.binstr, 2), prod_conf)

                result_binstr = dut.mac._id(signal_id_base + '.sum', extended=False).value.binstr
                result = AFloat.from_literal(int(result_binstr, 2), prod_conf).as_float()

                expected = X + Y
                expected_binstr = expected.binstr()
                expected = expected.as_float()

                assert expected == result, "{},{},{}: {} + {}; result={} ({}) expected={} ({})".format(i, level, j, X.as_float(), Y.as_float(), result, result_binstr, expected, expected_binstr)
        num_operands /= 2
        level -= 1
        await FallingEdge(dut.clk)

    for i in range(dut.K.value):
        signal_id_base = f'accumulators[{i}].acc.fpadd'
        X = AFloat.from_literal(int(dut.mac._id(signal_id_base + '.X', extended=False).value.binstr, 2), res_conf)
        Y = AFloat.from_literal(int(dut.mac._id(signal_id_base + '.Y', extended=False).value.binstr, 2), res_conf)

        result_binstr = dut.mac._id(signal_id_base + '.sum', extended=False).value.binstr
        result = AFloat.from_literal(int(result_binstr, 2), res_conf).as_float()

        expected = X.add(Y, result_config=res_conf)
        expected_binstr = expected.binstr()
        expected = expected.as_float()

        assert expected == result, "{},last,0: {} ({}) + {} ({}); result={} ({}) expected={} ({})".format(i, X.as_float(), X.binstr(), Y.as_float(), Y.binstr(), result, result_binstr, expected, expected_binstr)


def calc_matvec(dut, frame, weights):
    dut._log.debug('Calculating matvec result')
    prod_conf = AFloatConfig(dut.PROD_EWIDTH.value, dut.PROD_SIGWIDTH.value, nan_inf_support=False, subnormal_support=True)
    result_conf = AFloatConfig(dut.EWIDTH.value, dut.SIGWIDTH.value, nan_inf_support=False, subnormal_support=True)
    dut._log.debug('Multipliers...')
    mult_intermediates = weights.mul(AFloatArray(frame).as_config(config=AFloatConfig.ieee64()), result_config=prod_conf)
    mult_intermediates = mult_intermediates.as_config(result_conf)

    dut._log.debug('Accumulation...')
    for i in range(dut.K.value):
        dut._log.debug(f'Accumulation for PCA index {i}...')
        for j in range(dut.number_of_rows_per_frame.value):
            max = dut.number_of_columns_per_frame.value
            while max > 1:
                temp = AFloatArray(np.zeros(dut.number_of_columns_per_frame.value)).as_config(config=result_conf)
                for k in range(0, int(max / 2)):
                    temp[k] = mult_intermediates[i][j * dut.number_of_columns_per_frame.value + 2 * k].add(mult_intermediates[i][j * dut.number_of_columns_per_frame.value + 2 * k + 1], result_config=result_conf)
                mult_intermediates[i][j * dut.number_of_columns_per_frame.value:j * dut.number_of_columns_per_frame.value + dut.number_of_columns_per_frame.value] = temp
                max /= 2
                max = int(max)

    expected_vals = AFloatArray(np.zeros(dut.K.value)).as_config(config=result_conf)
    for i in range(dut.K.value):
        for j in range(dut.number_of_rows_per_frame.value):
            expected_vals[i] = expected_vals[i].add(mult_intermediates[i][j * dut.number_of_columns_per_frame.value], result_config=result_conf)

    dut._log.debug('Done calculating matvec result')

    return expected_vals


def validate_output(dut, expected_vals):
    err = 0.0
    res_conf = AFloatConfig(exponent_bits = dut.EWIDTH.value, mantissa_bits = dut.SIGWIDTH.value, nan_inf_support=False, subnormal_support=False)
    for i in range(dut.K.value):
        result_binstr = dut.result[dut.K.value - i - 1].value.binstr
        result = AFloat.from_literal(int(result_binstr, 2), res_conf).as_float()
        expected = expected_vals[i]
        expected_binstr = expected.binstr()
        expected = expected.as_float()
        assert expected == result, f'{i}: result={result} ({result_binstr}) expected={expected} ({expected_binstr})'
        err += abs(result - expected)
    err /= dut.K.value

    return err


async def delayed_validation(dut, expected_vals):
    for i in range(math.ceil(math.log2(dut.number_of_columns_per_frame.value)) + 2):
        await RisingEdge(dut.clk)

    return validate_output(dut, expected_vals)


@cocotb.test()
async def fixed_input_test(dut):
    sim_status = init(dut)
    await cocotb.start(generate_clock(dut, sim_status))
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    watchdog = cocotb.start_soon(invalid_signal_watchdog(dut, sim_status))

    frame = gen_all_ones_frame(dut)
    weights = gen_fixed_weights(dut)

    # calculate expected output
    expected_vals = calc_matvec(dut, frame, weights)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    # signal that the next frame is coming
    dut.SRO.value = 1
    await RisingEdge(dut.clk)
    dut.SRO.value = 0

    await write_frame(dut, frame, weights)

    err = await delayed_validation(dut, expected_vals)

    err *= 100.0
    print(f'average relative error = {err}%')

    sim_status.do_sim = False
    await RisingEdge(dut.clk)

    await watchdog.join()
    watchdog.result()


@cocotb.test()
async def random_test(dut):
    sim_status = init(dut)
    await cocotb.start(generate_clock(dut, sim_status))
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    watchdog = cocotb.start_soon(invalid_signal_watchdog(dut, sim_status))

    outer_iterations = 4
    for outer_iter in range(outer_iterations):
        dut._log.debug(f'Outer iter = {outer_iter}')
        weights = gen_random_weights(dut)

        await write_weights(dut, weights)

        # reset fsm
        dut.reset.value = 1
        await RisingEdge(dut.clk)
        dut.reset.value = 0

        iterations = 16
        tasks = []

        # signal that the first frame is coming
        dut.SRO.value = 1
        await RisingEdge(dut.clk)
        dut.SRO.value = 0
        for iter in range(iterations):
            dut._log.debug(f'Inner iter = {iter}')
            frame = gen_random_frame(dut)

            # calculate expected output
            expected_vals = calc_matvec(dut, frame, weights)

            # print_matvec(dut, weights, frame, expected_vals)

            await write_frame(dut, frame, weights, True, iter != iterations - 1)

            tasks.append(cocotb.start_soon(delayed_validation(dut, expected_vals)))

        for task in tasks:
            await task.join()
            task.result()

    sim_status.do_sim = False
    await RisingEdge(dut.clk)

    await watchdog.join()
    watchdog.result()


# @cocotb.test()
# async def invalid_signal_test(dut):
#     sim_status = init(dut)
#     await cocotb.start(generate_clock(dut, sim_status))
#     dut.reset.value = 1
#     await RisingEdge(dut.clk)
#     dut.reset.value = 0
#
#     # dv asserted when SRO has not been asserted is invalid
#     dut.dv.value = 1
#     await RisingEdge(dut.clk)
#     await FallingEdge(dut.clk)
#     assert(dut.SRO_invalid.value == 0)
#     assert(dut.dv_invalid.value == 1)
#     assert(dut.fsm.addr_reg.value == 0)
#
#     # move out of idle
#     dut.SRO.value = 1
#     dut.dv.value = 0
#     await FallingEdge(dut.clk)
#     dut.dv.value = 1
#     assert(dut.SRO_invalid.value == 0)
#     assert(dut.dv_invalid.value == 0)
#     assert(dut.fsm.addr_reg.value == 0)
#
#     # keeping SRO asserted after a cycle is invalid. Addr should start to increment
#     await FallingEdge(dut.clk)
#     for i in range(dut.number_of_rows_per_frame.value - 1):
#         assert(dut.SRO_invalid.value == 1)
#         assert(dut.dv_invalid.value == 0)
#         assert(dut.fsm.addr_reg.value != 0)
#         await FallingEdge(dut.clk)
#
#     # SRO asserted after last row is NOT invalid. Addr should be back to zero
#     assert(dut.SRO_invalid.value == 0)
#     assert(dut.dv_invalid.value == 0)
#     assert(dut.fsm.addr_reg.value == 0)
#
#     # unasserting SRO after a cycle is valid. Addr should start to increment
#     dut.SRO.value = 0
#     await FallingEdge(dut.clk)
#     for i in range(dut.number_of_rows_per_frame.value - 1):
#         assert(dut.SRO_invalid.value == 0)
#         assert(dut.dv_invalid.value == 0)
#         assert(dut.fsm.addr_reg.value != 0)
#         await FallingEdge(dut.clk)
#
#     # not reasserting SRO on the last row is valid. Addr should start to increment
#     assert(dut.SRO_invalid.value == 0)
#     assert(dut.dv_invalid.value == 0)
#     assert(dut.fsm.addr_reg.value == 0)
#
#     sim_status.do_sim = False


@cocotb.test()
async def adder_unit_test(dut):
    ebits, mbits = dut.EWIDTH.value, dut.SIGWIDTH.value
    conf = AFloatConfig(exponent_bits = ebits, mantissa_bits = mbits, nan_inf_support = False, subnormal_support=False)
    float_max_val = AFloat.from_literal(int('0' + '1' * (ebits + mbits), 2), conf).as_float()

    def format_binstr(value):
        """Format a binary string representing a floating point number into a human-friendly format with a delimiter between the sign, significand, and exponent."""
        return f"{value[-(ebits+mbits+1)]}|{value[-(ebits+mbits):-mbits]}|{value[-mbits:]}"

    async def check_addition(X_binstr, Y_binstr):
        # Zero subnormal values
        if X_binstr[-(mbits+ebits):-mbits] == '0' * ebits: X_binstr = '0' * (ebits + mbits + 1)
        if Y_binstr[-(mbits+ebits):-mbits] == '0' * ebits: Y_binstr = '0' * (ebits + mbits + 1)
        dut.X.value = int(X_binstr, 2)
        dut.Y.value = int(Y_binstr, 2)

        await Timer(1, units="ns")

        # print(format_binstr(X_binstr), '+', format_binstr(Y_binstr), '->', format_binstr(dut.sum.value.binstr))
        result = AFloat.from_literal(int(dut.sum.value.binstr, 2), conf).as_float()

        X_val = AFloat.from_literal(int(X_binstr, 2), conf)
        Y_val = AFloat.from_literal(int(Y_binstr, 2), conf)
        expected = X_val + Y_val
        if abs(expected.as_float()) > float_max_val:
            return
        expected_binstr = expected.binstr()

        # Compare calculated vs expected. Ignore sign for zero value, and overflow entirely
        assert dut.sum.value.binstr == expected_binstr \
                or (int(dut.sum.value.binstr[-(mbits+ebits):], 2) == int(expected_binstr[-(mbits+ebits):], 2) == 0), \
                f'Expected {expected.as_float()} ({format_binstr(expected_binstr)}), got {result} ({format_binstr(dut.sum.value.binstr)}) for {AFloat.from_literal(int(X_binstr, 2), conf).as_float()} + {AFloat.from_literal(int(Y_binstr, 2), conf).as_float()} ({format_binstr(X_binstr)}, {format_binstr(Y_binstr)})'


    # Test all 24000-ish combinations of sign, exponent, and mantissa
    # This is supposed to more reliably hit edge cases than random testing
    exponent_values = [1, 2, 3, 4, 5, 2**(ebits - 1) - 1, 2**(ebits - 1), 2**(ebits - 1) + 1, 2**ebits - 3, 2**ebits - 2, 2**ebits - 1]
    mantissa_values = [0, 1, 2, 2**(mbits - 1) - 1, 2**(mbits - 1), 2**mbits - 2, 2**mbits - 1]
    sign_values = [0, 1]

    for X_sign, X_exponent, X_mantissa in [(0,0,0)] + [(s, e, m) for s in sign_values for e in exponent_values for m in mantissa_values]:
        for Y_sign, Y_exponent, Y_mantissa in [(0,0,0)] + [(s, e, m) for s in sign_values for e in exponent_values for m in mantissa_values]:
            X_binstr = f"{X_sign}{X_exponent:0{ebits}b}{X_mantissa:0{mbits}b}"
            Y_binstr = f"{Y_sign}{Y_exponent:0{ebits}b}{Y_mantissa:0{mbits}b}"

            await check_addition(X_binstr, Y_binstr)

    # Also test random values
    for _ in range(10000):
        X = random.uniform(-float_max_val, float_max_val)
        Y = random.uniform(-float_max_val, float_max_val)
        X_binstr = AFloat.from_float(X, conf=conf).binstr()
        Y_binstr = AFloat.from_float(Y, conf=conf).binstr()
        await check_addition(X_binstr, Y_binstr)
