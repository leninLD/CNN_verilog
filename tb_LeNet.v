`timescale 1ns/1ps

`define TS 10
`define DELAY (`TS*2)
`define RunTime (`TS*8798)

module tb_LeNet;

reg clk;
reg rst;
wire [31:0] LeNet_Out;

LeNet uut(
    clk,
    rst,
    LeNet_Out
);

// Clock generation
initial begin
    clk = 0;
    forever #(`TS) clk = ~clk;
end

// Dump waveform
initial begin
    $dumpfile("LeNet.vcd");
    $dumpvars(0, tb_LeNet);
end

// Reset and finish
initial begin
    rst = 1;
    #(`DELAY);
    rst = 0;

    #(`RunTime);
    $display("Simulation Finished.");
    $finish;
end

// Print detected digit
always @(LeNet_Out)
begin

    if(LeNet_Out!=-1)

    begin

        $display("--------------------------------");

        $display("Detected Digit : %0d",LeNet_Out);

        $display("--------------------------------");

    end

end

endmodule