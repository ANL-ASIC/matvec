import cocotb, math
from cocotb.triggers import Timer, FallingEdge
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

@cocotb.test()
async def write_to_sram_and_multiply_with_ones(dut):
    init_signals(dut)
    await cocotb.start(generate_clock(dut));
    await FallingEdge(dut.clk);

    for addr in range(dut.number_of_rows_per_frame.value):

        dut.reset.value = 0
        dut.write_enable.value = 1
        dut.write_addr.value = addr

        # print("write_data is {} by {} elements".format(len(dut.write_data) / len(dut.write_data[0]), len(dut.write_data[0]) / len(dut.write_data[0][0])))
        write_data = ''
        for i in range(dut.K.value):
            for j in range(dut.number_of_columns_per_frame.value):
                # dut.write_data[i][j].value = int(float_to_bit_string(float((addr * dut.number_of_columns_per_frame.value) + j + 1), dut.EWIDTH.value, dut.SIGWIDTH.value), 2)
                write_data += float_to_bit_string(float((addr * dut.number_of_columns_per_frame.value) + j + 1), dut.EWIDTH.value, dut.SIGWIDTH.value)
        dut.write_data.value = BinaryValue(write_data)

        await FallingEdge(dut.clk);

    for i in range(dut.number_of_columns_per_frame.value):
        dut.pixel_data[i].value = 1
    dut.write_enable.value = 0
    dut.dv.value = 1
    dut.reset.value = 1
    dut.SRO.value = 1
    await FallingEdge(dut.clk);
    dut.reset.value = 0

    for i in range(dut.number_of_rows_per_frame.value + 1):
        await FallingEdge(dut.clk);

    expected = 0
    for i in range(dut.number_of_rows_per_frame.value):
        for j in range(dut.number_of_columns_per_frame.value):
            expected += dut.number_of_columns_per_frame.value * i + j + 1

    for i in range(dut.K.value):
        result = dut.result[i].value.binstr
        expected_str = float_to_bit_string(float(expected), dut.EWIDTH.value, dut.SIGWIDTH.value)
        print("{}: result={} ({}) expected={} ({})".format(i, result, bit_string_to_float(result, dut.EWIDTH.value), expected_str, expected))
        assert result == expected_str

    await FallingEdge(dut.clk);
    do_sim = False

for i in range(-16, 17):
    conv = float_to_bit_string(i, 8, 23)
    if int_to_fp32[i] != conv:
        print('For "{}", got "{}" but expected "{}"'.format(i, conv, int_to_fp32[i]))
    conv = bit_string_to_float(int_to_fp32[i], 8)
    if i != conv:
        print('For "{}", got "{}" but expected "{}"'.format(int_to_fp32[i], conv, i))
