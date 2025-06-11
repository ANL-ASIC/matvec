import cocotb, math, random
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
          16: "01000001100000000000000000000000"
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
    # dut.write_data.value = 0
    # dut.pixel_data.value = 0


def float_to_bit_string(val, exp_bits, sig_bits):
    result = ''
    if val == 0:
        result = ''.join(['0' * (exp_bits + sig_bits + 1)])
        return result

    (sig, exp) = math.frexp(val)


    # apply bias
    exp += 2 ** (exp_bits - 1) - 2

    # find integer with same bitstring as signficand
    sig = sig if sig >= 0 else -sig
    sig = sig * 2 ** (sig_bits - int(math.log2(sig)))
    if (sig < 2 ** sig_bits):
        sig = sig * 2
    sig = int(sig)

    # make sure this number is representable
    assert exp < (2 ** exp_bits)
    assert int(sig) == sig

    result = '{}{}{}'.format('0' if val >= 0 else '1', format(exp, '08b')[-exp_bits:], format(sig, '024b')[-sig_bits:])

    return result


def bit_string_to_float(string, exp_bits):
    sign = 1 if string[0] == '0' else -1
    exp = int(string[1:exp_bits + 1], 2)
    sig = int(('1' if exp != 0 else '0') + string[exp_bits + 1:], 2)
    sig = sig

    exp -= 2 ** (exp_bits - 1) - 1

    while sig >= 2:
        sig /= 2

    return sign * 2 ** exp * sig

def truncate_float(val, exp_bits, sig_bits):
    return bit_string_to_float(float_to_bit_string(val, exp_bits, sig_bits), 8)


def gen_random_frame(dut):
    frame = [0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value
    for i in range(dut.number_of_rows_per_frame.value):
        # set full row
        for j in range(dut.number_of_columns_per_frame.value):
            frame[dut.number_of_columns_per_frame.value * i + j] = random.randint(0, 2 ** dut.pixel_data_width.value - 1)
    return frame


def gen_all_ones_frame(dut):
    frame = [0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value
    for i in range(dut.number_of_rows_per_frame.value):
        # set full row
        for j in range(dut.number_of_columns_per_frame.value):
            frame[dut.number_of_columns_per_frame.value * i + j] = 1
    return frame


def gen_random_weights(dut):
    # generate weight randomly
    weights = [[0.0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value] * dut.K.value
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            weights[i][j] = truncate_float(random.uniform(-1, 1), dut.EWIDTH.value, dut.SIGWIDTH.value)
    return weights


def gen_ascending_weights(dut):
    # generate weight randomly
    weights = [[0.0] * dut.number_of_rows_per_frame.value * dut.number_of_columns_per_frame.value] * dut.K.value
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            weights[i][j] = float(j + 1)
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
                # We have to write the words in backwards order because of how the packed array is physically ordered
                write_data += float_to_bit_string(weights[i][dut.number_of_columns_per_frame.value * addr + (dut.number_of_columns_per_frame.value - j - 1)], dut.EWIDTH.value, dut.SIGWIDTH.value)
        dut.write_data.value = BinaryValue(write_data)

        await RisingEdge(dut.clk)

    dut.write_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.K.value * (1 + dut.EWIDTH.value + dut.SIGWIDTH.value)) + 'b'))
    dut.write_enable.value = 0


async def write_frame(dut, frame):
    dut.SRO.value = 1
    dut.dv.value = 1

    await RisingEdge(dut.clk)

    # set full frame
    for i in range(dut.number_of_rows_per_frame.value):
        # set full row
        for j in range(dut.number_of_columns_per_frame.value):
            dut.pixel_data[j].value = frame[dut.number_of_columns_per_frame.value * i + j]

        await RisingEdge(dut.clk)

    dut.pixel_data.value = BinaryValue(format(0, '0' + str(dut.number_of_columns_per_frame.value * dut.pixel_data_width.value) + 'b'))

    await RisingEdge(dut.clk)


def calc_matvec(dut, frame, weights):
    expected_vals = [0.0] * dut.K.value
    for i in range(dut.K.value):
        for j in range(dut.number_of_columns_per_frame.value  * dut.number_of_rows_per_frame.value):
            expected_vals[i] += weights[i][j] * frame[j]

    return expected_vals


def validate_output(dut, expected_vals):
    for i in range(dut.K.value):
        result_str = dut.result[i].value.binstr
        result = bit_string_to_float(result_str, dut.EWIDTH.value)
        expected_str = float_to_bit_string(float(expected_vals[i]), dut.EWIDTH.value, dut.SIGWIDTH.value)
        print("{}: result={} ({}) expected={} ({})".format(i, result_str, result, expected_str, expected_vals[i]))
        assert ((expected_vals[i] >= 0) and (result > .99999 * expected_vals[i]) and (result < 1.00001 * expected_vals[i])) or ((expected_vals[i] < 0) and (result < .99999 * expected_vals[i]) and (result > 1.00001 * expected_vals[i]))


@cocotb.test()
async def fixed_input_test(dut):
    init_signals(dut)
    await cocotb.start(generate_clock(dut))
    await RisingEdge(dut.clk)

    frame = gen_all_ones_frame(dut)
    weights = gen_ascending_weights(dut)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    await write_frame(dut, frame)

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

    frame = gen_random_frame(dut)
    weights = gen_random_weights(dut)

    await write_weights(dut, weights)

    # reset fsm
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    await write_frame(dut, frame)

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

    # calculate expected output
    expected_vals = calc_matvec(dut, frame, weights)

    validate_output(dut, expected_vals)

    await RisingEdge(dut.clk)
    do_sim = False


for i in range(-16, 17):
    conv = float_to_bit_string(i, 8, 23)
    if int_to_fp32[i] != conv:
        print('For "{}", got "{}" but expected "{}"'.format(i, conv, int_to_fp32[i]))
    assert int_to_fp32[i] == conv
    conv = bit_string_to_float(int_to_fp32[i], 8)
    if i != conv:
        print('For "{}", got "{}" but expected "{}"'.format(int_to_fp32[i], conv, i))
    assert i == conv
