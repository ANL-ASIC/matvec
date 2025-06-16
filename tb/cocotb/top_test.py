import cocotb, math, random, numpy
from cocotb.triggers import Timer, RisingEdge
from cocotb.binary import BinaryValue

do_sim = True
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

async def generate_clock(dut):
    while do_sim:
        dut.clk.value = 0
        await Timer(1, units="ns")
        dut.clk.value = 1
        await Timer(1, units="ns")


def init_signals(dut):
    dut.clk.value = 0
    dut.reset.value = 0
    dut.SRO.value = 0
    dut.dv.value = 0
    dut.write_enable.value = 0
    dut.write_addr.value = 0


def get_exp_and_sig(val):
    if val == 0.0:
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


def float_to_bit_string(val, exp_bits, sig_bits):
    result = ''
    if val == 0.0:
        return format(0, '0' + str(exp_bits + sig_bits + 1) + 'b')

    (exp, sig) = get_exp_and_sig(val)

    # make sure this number is representable
    assert sig > (2 ** (-sig_bits))
    assert exp > -(2 ** (exp_bits - 1))

    # apply bias
    exp += 2 ** (exp_bits - 1) - 1

    # find integer with same bitstring as signficand
    sig = sig * 2 ** ((sig_bits + 1) - int(math.log2(sig))) # sig_bits + 1 because of the hidden bit
    sig = int(sig)

    result = '{}{}{}'.format('0' if val >= 0 else '1', format(exp, '0' + str(exp_bits) + 'b')[:exp_bits], format(sig, '0' + str(sig_bits) + 'b')[1:sig_bits + 1])

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


def gen_random_frame(dut):
    rng = numpy.random.default_rng()
    return rng.normal(loc=(2 ** (dut.pixel_data_width.value - 1) - .5), scale=(2 ** dut.pixel_data_width.value / 6), size=(dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value)).astype(int)


def gen_all_ones_frame(dut):
    frame = [0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value
    for i in range(dut.number_of_rows_per_frame.value):
        # set full row
        for j in range(dut.number_of_columns_per_frame.value):
            frame[dut.number_of_columns_per_frame.value * i + j] = 1
    return frame


def gen_random_weights(dut):
    weights = []
    for i in range(dut.K.value):
        weights.append([0.0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value)

    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            weights[i][j] = truncate_float(random.uniform(-1, 1), dut.EWIDTH.value, dut.SIGWIDTH.value)
    return weights


def gen_ascending_weights(dut):
    weights = []
    for i in range(dut.K.value):
        weights.append([0.0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value)

    weights = [[0.0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value] * dut.K.value
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            weights[i][j] = float((j / 2 + 1) * (2**6 if j % 2 == 0 else -2**-6))
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


async def write_frame(dut, frame):
    dut.SRO.value = 1
    # dut.dv.value = 1

    await RisingEdge(dut.clk)

    # set full frame
    i = 0
    while i < dut.number_of_rows_per_frame.value:
        if random.randint(0, 1) == 1:
            dut.dv.value = 1
            binstr = ''
            # set full row
            for j in range(dut.number_of_columns_per_frame.value):
                binstr += format(frame[dut.number_of_columns_per_frame.value * i + (dut.number_of_columns_per_frame.value - j - 1)], '0' + str(dut.pixel_data_width.value) + 'b')
            dut.pixel_data.value = BinaryValue(binstr)
            i += 1
        else:
            dut.dv.value = 0
            dut.pixel_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.pixel_data_width.value) + 'b'))

        await RisingEdge(dut.clk)

    dut.pixel_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.pixel_data_width.value) + 'b'))
    dut.SRO.value = 0
    dut.dv.value = 0

    await RisingEdge(dut.clk)


def calc_matvec(dut, frame, weights):
    expected_vals = [0.0] * dut.K.value
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            expected_vals[i] += weights[i][j] * frame[j]

    return expected_vals


def validate_output(dut, expected_vals):
    for i in range(dut.K.value):
        result_binstr = dut.result[dut.K.value - i - 1].value.binstr
        result = bit_string_to_float(result_binstr, dut.EWIDTH.value)
        expected_binstr = float_to_bit_string(expected_vals[i], dut.EWIDTH.value, dut.SIGWIDTH.value)
        print("{}: result={} ({}) expected={} ({})".format(i, result, result_binstr, expected_vals[i], expected_binstr))
        assert ((expected_vals[i] >= 0) and (result > .999 * expected_vals[i]) and (result < 1.001 * expected_vals[i])) or ((expected_vals[i] < 0) and (result < .999 * expected_vals[i]) and (result > 1.001 * expected_vals[i]))


@cocotb.test()
async def fixed_input_test(dut):
    init_signals(dut)
    await cocotb.start(generate_clock(dut))
    await RisingEdge(dut.clk)

    frame = gen_all_ones_frame(dut)
    weights = gen_ascending_weights(dut)

    # printstr = ''
    # for i in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
    #     printstr += str(frame[i]) + ' '
    # print(printstr)
    # print('')

    # for i in range(dut.K.value):
    #     printstr = ''
    #     for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
    #         printstr += str(weights[i][j]) + ' '
    #     print(printstr)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    await write_frame(dut, frame)

    for i in range(math.ceil(math.log2(dut.number_of_columns_per_frame.value))):
        await RisingEdge(dut.clk)

    # calculate expected output
    expected_vals = calc_matvec(dut, frame, weights)

    validate_output(dut, expected_vals)

    await RisingEdge(dut.clk)
    do_sim = False


@cocotb.test()
async def random_test(dut):
    init_signals(dut)
    await cocotb.start(generate_clock(dut))
    await RisingEdge(dut.clk)

    weights = gen_random_weights(dut)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    for iter in range(128):
        frame = gen_random_frame(dut)

        printstr = ''
        for i in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            printstr += str(frame[i]) + ' '
        print(printstr)
        print('')

        for i in range(dut.K.value):
            printstr = ''
            for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
                printstr += str(weights[i][j]) + ' '
            print(printstr)

        await write_frame(dut, frame)

        for i in range(math.ceil(math.log2(dut.number_of_columns_per_frame.value))):
            await RisingEdge(dut.clk)

        # calculate expected output
        expected_vals = calc_matvec(dut, frame, weights)

        validate_output(dut, expected_vals)

    await RisingEdge(dut.clk)
    do_sim = False


for (val, bitstr) in int_to_fp32.items():
    conv = float_to_bit_string(val, 8, 23)
    if bitstr != conv:
        print('For "{}", got "{}" but expected "{}"'.format(val, conv, bitstr))
    assert bitstr == conv
    conv = bit_string_to_float(bitstr, 8)
    if val != conv:
        print('For "{}", got "{}" but expected "{}"'.format(bitstr, conv, val))
    assert val == conv
