`timescale 1ns/1ps

module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 5
)(
    // =========================================================
    // WRITE CLOCK DOMAIN
    // =========================================================
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] data_in,

    output logic                  full,

    // =========================================================
    // READ CLOCK DOMAIN
    // =========================================================
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,

    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  empty
);

    // =========================================================
    // PARAMETERS
    // =========================================================

    localparam int DEPTH    = (1 << ADDR_WIDTH);
    localparam int PTR_WIDTH = ADDR_WIDTH + 1;

    // =========================================================
    // FIFO MEMORY
    //
    // For FPGA, this can infer dual-port RAM depending on tool.
    // For ASIC, this can later be replaced by an SRAM macro.
    // =========================================================

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // =========================================================
    // BINARY POINTERS
    // =========================================================

    logic [PTR_WIDTH-1:0] wr_ptr_bin;
    logic [PTR_WIDTH-1:0] rd_ptr_bin;

    logic [PTR_WIDTH-1:0] wr_ptr_bin_next;
    logic [PTR_WIDTH-1:0] rd_ptr_bin_next;

    // =========================================================
    // GRAY POINTERS
    // =========================================================

    logic [PTR_WIDTH-1:0] wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_gray;

    logic [PTR_WIDTH-1:0] wr_ptr_gray_next;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_next;

    // =========================================================
    // SYNCHRONIZED POINTERS
    //
    // Read pointer crosses into write domain.
    // Write pointer crosses into read domain.
    // =========================================================

    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync;

    // =========================================================
    // ACTUAL FIFO OPERATIONS
    //
    // A write is accepted only when FIFO isn't full.
    // A read is accepted only when FIFO isn't empty.
    // =========================================================

    logic write_accept;
    logic read_accept;

    assign write_accept = wr_en && !full;
    assign read_accept  = rd_en && !empty;

    // =========================================================
    // NEXT BINARY POINTERS
    // =========================================================

    assign wr_ptr_bin_next =
        wr_ptr_bin + {{(PTR_WIDTH-1){1'b0}}, write_accept};

    assign rd_ptr_bin_next =
        rd_ptr_bin + {{(PTR_WIDTH-1){1'b0}}, read_accept};

    // =========================================================
    // BINARY -> GRAY
    //
    // gray = binary ^ (binary >> 1)
    // =========================================================

    assign wr_ptr_gray_next =
        wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    assign rd_ptr_gray_next =
        rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    // =========================================================
    // WRITE POINTER REGISTER
    // =========================================================

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end
        else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // =========================================================
    // READ POINTER REGISTER
    // =========================================================

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end
        else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // =========================================================
    // MEMORY WRITE
    //
    // Lower ADDR_WIDTH bits address the memory.
    // =========================================================

    always_ff @(posedge wr_clk) begin
        if (write_accept) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
        end
    end

    // =========================================================
    // MEMORY READ
    //
    // Synchronous read.
    // =========================================================

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            data_out <= '0;
        end
        else if (read_accept) begin
            data_out <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        end
    end

    // =========================================================
    // CDC:
    // READ POINTER -> WRITE DOMAIN
    // =========================================================

    cdc_sync_2ff #(
        .WIDTH(PTR_WIDTH)
    ) u_rdptr_sync (
        .clk      (wr_clk),
        .rst_n    (wr_rst_n),
        .async_in (rd_ptr_gray),
        .sync_out (rd_ptr_gray_sync)
    );

    // =========================================================
    // CDC:
    // WRITE POINTER -> READ DOMAIN
    // =========================================================

    cdc_sync_2ff #(
        .WIDTH(PTR_WIDTH)
    ) u_wrptr_sync (
        .clk      (rd_clk),
        .rst_n    (rd_rst_n),
        .async_in (wr_ptr_gray),
        .sync_out (wr_ptr_gray_sync)
    );

    // =========================================================
    // EMPTY DETECTION
    //
    // FIFO becomes empty when the NEXT read pointer equals
    // the synchronized write pointer.
    // =========================================================

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            empty <= 1'b1;
        end
        else begin
            empty <= (rd_ptr_gray_next == wr_ptr_gray_sync);
        end
    end

    // =========================================================
    // FULL DETECTION
    //
    // For Gray-coded asynchronous FIFO:
    //
    // FULL occurs when next write pointer equals the
    // synchronized read pointer with its two MSBs inverted.
    //
    // Pointer width must be >= 2.
    // =========================================================

    logic [PTR_WIDTH-1:0] rd_ptr_gray_full_cmp;

    assign rd_ptr_gray_full_cmp = {
        ~rd_ptr_gray_sync[PTR_WIDTH-1:PTR_WIDTH-2],
         rd_ptr_gray_sync[PTR_WIDTH-3:0]
    };

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            full <= 1'b0;
        end
        else begin
            full <= (wr_ptr_gray_next == rd_ptr_gray_full_cmp);
        end
    end

    // =========================================================
    // OPTIONAL INTERNAL STATUS SIGNALS
    //
    // Useful while debugging in Vivado.
    // =========================================================

`ifdef FIFO_DEBUG

    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [ADDR_WIDTH-1:0] rd_addr;

    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];
    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

`endif

endmodule