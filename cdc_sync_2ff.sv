`timescale 1ns/1ps

module cdc_sync_2ff #(
    parameter WIDTH = 1
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] async_in,
    output logic [WIDTH-1:0] sync_out
);

    // ASYNC_REG tells FPGA/ASIC tools that these registers
    // form a CDC synchronizer chain.
    (* ASYNC_REG = "TRUE" *)
    logic [WIDTH-1:0] sync_ff1;

    (* ASYNC_REG = "TRUE" *)
    logic [WIDTH-1:0] sync_ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= '0;
            sync_ff2 <= '0;
        end
        else begin
            sync_ff1 <= async_in;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sync_out = sync_ff2;

endmodule