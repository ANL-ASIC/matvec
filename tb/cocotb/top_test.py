import cocotb
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge

do_sim = True
int_to_fp32 = (
        "00000000000000000000000000000000", # 0
        "00111111100000000000000000000000", # 1
        "01000000000000000000000000000000", # 2
        "01000000010000000000000000000000", # 3
        "01000000100000000000000000000000", # 4
        "01000000101000000000000000000000", # 5
        "01000000110000000000000000000000", # 6
        "01000000111000000000000000000000", # 7
        "01000001000000000000000000000000", # 8
        "01000001000100000000000000000000", # 9
        "01000001001000000000000000000000", # 10
        "01000001001100000000000000000000", # 11
        "01000001010000000000000000000000", # 12
        "01000001010100000000000000000000", # 13
        "01000001011000000000000000000000", # 14
        "01000001011100000000000000000000", # 15
        "01000001100000000000000000000000" # 16
        )

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


@cocotb.test()
async def write_to_sram_and_multiply_with_ones(dut):
    init_signals(dut)
    await cocotb.start(generate_clock(dut));
    await FallingEdge(dut.clk);

    for addr in range(dut.number_of_rows_per_frame.value):

        dut.reset.value = 0
        dut.write_enable.value = 1
        dut.write_addr.value = addr
        for i in range(dut.K.value):
            for j in range(dut.number_of_columns_per_frame.value):
                dut.write_data[i][j].value = int(int_to_fp32[addr + 1], 2)

        await FallingEdge(dut.clk);

    for i in range(dut.number_of_columns_per_frame.value):
        dut.pixel_data[i].value = 1
    dut.write_enable.value = 0
    dut.dv.value = 1
    dut.reset.value = 1
    dut.SRO.value = 1
    await FallingEdge(dut.clk);
    dut.reset.value = 0

    await FallingEdge(dut.clk);
    await FallingEdge(dut.clk);
    await FallingEdge(dut.clk);

    expected = 0
    for addr in range(dut.number_of_rows_per_frame.value):
        expected += (dut.number_of_columns_per_frame.value * (addr + 1))

    for i in range(dut.K.value):
        result = dut.result[i].value.binstr
        expected_str = int_to_fp32[expected]
        print("{}: result={} expected={}".format(i, result, expected_str))
        assert result == expected_str

    await FallingEdge(dut.clk);
    do_sim = False
