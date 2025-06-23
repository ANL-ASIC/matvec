import cocotb, math, random
import numpy as np
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.binary import BinaryValue
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


def float_to_bit_string(val, exp_bits, sig_bits, zero_subnormals=False):
    result = ''
    if val == 0.0:
        return format(0, '0' + str(exp_bits + sig_bits + 1) + 'b')

    (exp, sig) = get_exp_and_sig(val)

    # Set subnormals to zero
    if zero_subnormals and -(2 ** (exp_bits - 1)) - sig_bits < exp <= -(2 ** (exp_bits - 1)):
        exp = 0
        sig = 0

    if exp == 0 and sig == 0: return '0' * (exp_bits + sig_bits + 1)

    # make sure this number is representable
    assert sig > (2 ** (-sig_bits))
    assert exp > -(2 ** (exp_bits - 1))

    # apply bias
    exp += 2 ** (exp_bits - 1) - 1

    # find integer with same bitstring as signficand
    sig_64 = int(sig * (2 ** (52)))  # Get the significand in 64-bit representation (python native)

    if sig_bits < 52:
        sig_64_sticky = sig_64 % (1 << (52 - sig_bits - 1)) != 0  # Get the sticky bits
        sig_64_guard = (sig_64 >> (52 - sig_bits - 1)) & 1  # Get the guard bit
        sig_64_odd = (sig_64 >> (52 - sig_bits)) & 1  # Get the odd bit

        sig = (sig_64 >> (52 - sig_bits))  # Get the significand in the correct bit representation
        if (sig_64_sticky and sig_64_guard) or (sig_64_guard and sig_64_odd):
            # round up if necessary
            sig += 1

        if sig >= (1 << (sig_bits + 1)): # Rounding caused overflow
            sig //= 2  # If the significand is larger than 1, we need to shift it right by one bit
            exp += 1  # and increase the exponent by one
    else:
        sig = sig_64

    sig &= (1 << sig_bits) - 1  # Mask the significand to the correct number of bits

    if zero_subnormals and exp == 0: sig, val = 0, 0

    result = f"{0 if val >= 0 else 1:1b}{exp:0{exp_bits}b}{sig:0{sig_bits}b}"

    return result


def bit_string_to_float(string, exp_bits):
    sign = 1 if string[0] == '0' else -1
    exp = int(string[1:exp_bits + 1], 2)
    sig = ('1' if exp != 0 else '0') + string[exp_bits + 1:]

    # remove bias
    exp -= 2 ** (exp_bits - 1) - 1

    sig_float = 0.0
    operand = 1.0
    for i in range(len(sig)):
        if sig[i] == '1':
            sig_float += operand
        operand /= 2.0

    return float(sign) * float(2 ** exp) * sig_float


def truncate_float(val, exp_bits, sig_bits):
    result = ''
    if val == 0:
        return format(0, '0' + str(exp_bits + sig_bits + 1) + 'b')

    (exp, sig) = get_exp_and_sig(val)

    min_exp = -(2 ** (exp_bits - 1) - 1)
    if exp <= min_exp:
        # print(f'{val} has an exponent of {exp}, smaller than {min_exp}, so rounding to 0')
        return 0;

    max_exp = 2 ** (exp_bits - 1) - 1
    if exp >= max_exp:
        # print(f'{val} has an exponent of {exp}, greater than {max_exp}, so rounding to largest possible value')
        fraction = 0.0
        operand = 1.0
        for i in range(sig_bits):
            operand /= 2
            fraction += operand
        return (1.0 if val >= 0 else -1.0) * float(2 ** (exp_bits - 1)) * (1.0 + fraction)

    return bit_string_to_float(float_to_bit_string(val, exp_bits, sig_bits), exp_bits)


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
    rng = np.random.default_rng(random.randint(0, 2 ** 32 - 1)) # Derive random state from python's random module to make runs reproducible
    weights = rng.uniform(low=-1.0, high=1.0, size=(dut.K.value, dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value))
    weights = np.where(weights < 1.0 * 2 ** (1 - (2 ** (dut.EWIDTH.value - 1) - 1)), 0, weights)
    if (dut.EWIDTH.value + dut.SIGWIDTH.value + 1 <= 16):
        weights = weights.astype(np.float16)

    return weights


def gen_ascending_weights(dut):
    dtype = get_float_np_type(dut)
    weights = np.zeros((dut.K.value, dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value), dtype=dtype)
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            weights[i][j] = dtype((j / 2 + 1) * (2**6 if j % 2 == 0 else -2**-6))
    return weights


async def write_weights(dut, weights):
    # write weights to SRAM
    dut.write_enable.value = 1
    for addr in range(dut.number_of_rows_per_frame.value):
        dut.write_addr.value = addr

        # print("write_data is {} by {} elements".format(len(dut.write_data) / len(dut.write_data[0]), len(dut.write_data[0]) / len(dut.write_data[0][0])))
        write_data = ''
        for i in range(dut.K.value):
            for j in range(dut.number_of_columns_per_frame.value):
                # We have to write the words in backwards order because the least significant work (index 0 of the array) is the end of the bit string
                write_data += float_to_bit_string(weights[i][dut.number_of_columns_per_frame.value * addr + (dut.number_of_columns_per_frame.value - j - 1)], dut.EWIDTH.value, dut.SIGWIDTH.value)
        # print(f"Writing weights: {write_data}")
        dut.write_data.value = BinaryValue(write_data)

        await RisingEdge(dut.clk)

    dut.write_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.K.value * (1 + dut.EWIDTH.value + dut.SIGWIDTH.value)) + 'b'))
    dut.write_enable.value = 0


async def write_frame(dut, frame, weights, always_valid = False, is_pipelined = False):
    # set full frame
    i = 0
    while i < dut.number_of_rows_per_frame.value:
        set_dv_high = always_valid or random.randint(0, 1) == 1
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
            await cocotb.start(validate_multiplies(dut, row, weights_row))
            await cocotb.start(validate_tree(dut))

    dut.pixel_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.pixel_data_width.value) + 'b'))
    dut.dv.value = 0


async def validate_multiplies(dut, row, weights):
    dtype = get_float_np_type(dut)
    row = row.astype(dtype)
    weights = weights.astype(dtype)
    width = dut.EWIDTH.value + dut.SIGWIDTH.value + 1
    result_binstrs = signal_to_np_array_2D(dut.mac.mult_intermediates.value.binstr, dut.K.value, dut.number_of_columns_per_frame.value, width)

    for i in range(dut.K.value):
        expected_vals = row * weights[i]
        for j in range(dut.number_of_columns_per_frame.value):
            result_binstr = result_binstrs[i][j]
            result = bit_string_to_float(result_binstr, dut.EWIDTH.value)
            expected = expected_vals[j]
            expected_binstr = float_to_bit_string(expected, dut.EWIDTH.value, dut.SIGWIDTH.value)
            if expected != result:
                print("{}, {}: {} * {}; result={} ({}) expected={} ({})".format(i, j, int(row[j]), weights[i][j], result, result_binstr, expected, expected_binstr))
            assert expected == result


async def validate_tree(dut):
    dtype = get_float_np_type(dut)
    num_operands = dut.number_of_columns_per_frame.value
    level = int(math.log2(num_operands)) - 1
    await FallingEdge(dut.clk)
    while num_operands > 1:
        for i in range(dut.K.value):
            for j in range(int(num_operands / 2)):
                signal_id_base = 'accumulators[{}].acc.acc_lvls[{}].acc_rows[{}].'.format(i, level, j) + ('first_lvl' if level == int(math.log2(dut.number_of_columns_per_frame.value)) - 1 else 'lvls') + '.fpadd'
                X = bit_string_to_float(dut.mac._id(signal_id_base + '.X', extended=False).value.binstr, dut.EWIDTH.value)
                Y = bit_string_to_float(dut.mac._id(signal_id_base + '.Y', extended=False).value.binstr, dut.EWIDTH.value)

                result_binstr = dut.mac._id(signal_id_base + '.sum', extended=False).value.binstr
                result = bit_string_to_float(result_binstr, dut.EWIDTH.value)

                expected = np.array([X], dtype=dtype) + np.array([Y], dtype=dtype)
                expected = expected[0]
                expected_binstr = float_to_bit_string(expected, dut.EWIDTH.value, dut.SIGWIDTH.value)

                if expected != result:
                    print("{},{},{}: {} + {}; result={} ({}) expected={} ({})".format(i, level, j, X, Y, result, result_binstr, expected, expected_binstr))
                assert expected == result
        num_operands /= 2
        level -= 1
        await FallingEdge(dut.clk)


def calc_matvec(dut, frame, weights):
    dtype = get_float_np_type(dut)
    frame = frame.astype(dtype)
    weights = weights.astype(dtype)
    expected_vals = np.zeros(dut.K.value, dtype=dtype)

    mult_intermediates = weights * frame

    for i in range(dut.K.value):
        for j in range(dut.number_of_rows_per_frame.value):
            max = dut.number_of_columns_per_frame.value
            while max > 1:
                temp = np.zeros(dut.number_of_columns_per_frame.value, dtype=type)
                for k in range(0, int(max / 2)):
                    temp[k] = mult_intermediates[i][j * dut.number_of_columns_per_frame.value + 2 * k] + mult_intermediates[i][j * dut.number_of_columns_per_frame.value + 2 * k + 1]
                mult_intermediates[i][j * dut.number_of_columns_per_frame.value:j * dut.number_of_columns_per_frame.value + dut.number_of_columns_per_frame.value] = temp
                max /= 2
                max = int(max)

    for i in range(dut.K.value):
        for j in range(dut.number_of_rows_per_frame.value):
            expected_vals[i] += mult_intermediates[i][j * dut.number_of_columns_per_frame.value]

    return expected_vals.astype(dtype)


def validate_output(dut, expected_vals):
    err = 0.0
    for i in range(dut.K.value):
        result_binstr = dut.result[dut.K.value - i - 1].value.binstr
        result = bit_string_to_float(result_binstr, dut.EWIDTH.value)
        expected = expected_vals[i]
        expected_binstr = float_to_bit_string(expected, dut.EWIDTH.value, dut.SIGWIDTH.value)
        if expected != result:
            print("{}: result={} ({}) expected={} ({})".format(i, result, result_binstr, expected, expected_binstr))
        assert expected == result
        err += abs(result - expected_vals[i])
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
    weights = gen_ascending_weights(dut)

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

    weights = gen_random_weights(dut)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    iterations = 128
    tasks = []

    # signal that the first frame is coming
    dut.SRO.value = 1
    await RisingEdge(dut.clk)
    dut.SRO.value = 0
    for iter in range(iterations):
        frame = gen_random_frame(dut)

        # calculate expected output
        expected_vals = calc_matvec(dut, frame, weights)

        await write_frame(dut, frame, weights, False, True)

        tasks.append(cocotb.start_soon(delayed_validation(dut, expected_vals)))

    err = 0.0
    for task in tasks:
        await task.join()
        err += task.result()

    err /= iterations
    err *= 100.0
    print(f'average relative error = {err}%')

    sim_status.do_sim = False
    await RisingEdge(dut.clk)

    await watchdog.join()
    watchdog.result()


@cocotb.test()
async def max_throughput_test(dut):
    sim_status = init(dut)
    await cocotb.start(generate_clock(dut, sim_status))
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    watchdog = cocotb.start_soon(invalid_signal_watchdog(dut, sim_status))

    weights = gen_random_weights(dut)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    iterations = 128
    tasks = []

    # signal that the first frame is coming
    dut.SRO.value = 1
    await RisingEdge(dut.clk)
    dut.SRO.value = 0
    for iter in range(iterations):
        frame = gen_random_frame(dut)

        # calculate expected output
        expected_vals = calc_matvec(dut, frame, weights)

        await write_frame(dut, frame, weights, True, True)

        tasks.append(cocotb.start_soon(delayed_validation(dut, expected_vals)))

    err = 0.0
    for task in tasks:
        await task.join()
        err += task.result()

    err /= iterations
    err *= 100.0
    print(f'average relative error = {err}%')

    sim_status.do_sim = False
    await RisingEdge(dut.clk)

    await watchdog.join()
    watchdog.result()


@cocotb.test()
async def invalid_signal_test(dut):
    sim_status = init(dut)
    await cocotb.start(generate_clock(dut, sim_status))
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    # dv asserted when SRO has not been asserted is invalid
    dut.dv.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert(dut.SRO_invalid.value == 0)
    assert(dut.dv_invalid.value == 1)
    assert(dut.fsm.addr_reg.value == 0)

    # move out of idle
    dut.SRO.value = 1
    dut.dv.value = 0
    await FallingEdge(dut.clk)
    dut.dv.value = 1
    assert(dut.SRO_invalid.value == 0)
    assert(dut.dv_invalid.value == 0)
    assert(dut.fsm.addr_reg.value == 0)

    # keeping SRO asserted after a cycle is invalid. Addr should start to increment
    await FallingEdge(dut.clk)
    for i in range(dut.number_of_rows_per_frame.value - 1):
        assert(dut.SRO_invalid.value == 1)
        assert(dut.dv_invalid.value == 0)
        assert(dut.fsm.addr_reg.value != 0)
        await FallingEdge(dut.clk)

    # SRO asserted after last row is NOT invalid. Addr should be back to zero
    assert(dut.SRO_invalid.value == 0)
    assert(dut.dv_invalid.value == 0)
    assert(dut.fsm.addr_reg.value == 0)

    # unasserting SRO after a cycle is valid. Addr should start to increment
    dut.SRO.value = 0
    await FallingEdge(dut.clk)
    for i in range(dut.number_of_rows_per_frame.value - 1):
        assert(dut.SRO_invalid.value == 0)
        assert(dut.dv_invalid.value == 0)
        assert(dut.fsm.addr_reg.value != 0)
        await FallingEdge(dut.clk)

    # not reasserting SRO on the last row is valid. Addr should start to increment
    assert(dut.SRO_invalid.value == 0)
    assert(dut.dv_invalid.value == 0)
    assert(dut.fsm.addr_reg.value == 0)

    sim_status.do_sim = False


@cocotb.test()
async def adder_unit_test(dut):
    ebits, mbits = dut.EWIDTH.value, dut.SIGWIDTH.value
    float_max_val = bit_string_to_float('0' + '1' * (ebits + mbits), ebits)

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
        result = bit_string_to_float(dut.sum.value.binstr, ebits)

        expected = bit_string_to_float(X_binstr, ebits) + bit_string_to_float(Y_binstr, ebits)
        expected_binstr = float_to_bit_string(expected, ebits, mbits, zero_subnormals=True)

        # Compare calculated vs expected. Ignore sign for zero value, and overflow entirely
        assert dut.sum.value.binstr == expected_binstr \
                or (int(dut.sum.value.binstr[-(mbits+ebits):], 2) == int(expected_binstr[-(mbits+ebits):], 2) == 0) \
                or abs(expected) > float_max_val, \
                f'Expected {bit_string_to_float(expected_binstr, ebits)} ({format_binstr(expected_binstr)}), got {result} ({format_binstr(dut.sum.value.binstr)}) for {bit_string_to_float(X_binstr, ebits)} + {bit_string_to_float(Y_binstr, ebits)} ({format_binstr(X_binstr)}, {format_binstr(Y_binstr)})'


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
        X_binstr = float_to_bit_string(X, ebits, mbits)
        Y_binstr = float_to_bit_string(Y, ebits, mbits)
        await check_addition(X_binstr, Y_binstr)


for (val, bitstr) in int_to_fp32.items():
    conv = float_to_bit_string(val, 8, 23)
    if bitstr != conv:
        print('For "{}", got "{}" but expected "{}"'.format(val, conv, bitstr))
    assert bitstr == conv
    conv = bit_string_to_float(bitstr, 8)
    if val != conv:
        print('For "{}", got "{}" but expected "{}"'.format(bitstr, conv, val))
    assert val == conv
