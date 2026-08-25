`timescale 1ns/1ps

module tb_async_fifo;

    // =========================================================
    // PARAMETERS
    // =========================================================

    localparam integer DATA_WIDTH = 32;
    localparam integer ADDR_WIDTH = 5;
    localparam integer DEPTH      = 1 << ADDR_WIDTH;

    // =========================================================
    // DUT SIGNALS
    // =========================================================

    logic wr_clk;
    logic rd_clk;

    logic wr_rst_n;
    logic rd_rst_n;

    logic wr_en;
    logic rd_en;

    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;

    logic full;
    logic empty;

    // =========================================================
    // REFERENCE FIFO
    // =========================================================

    logic [DATA_WIDTH-1:0] expected_queue[$];

    integer errors;
    integer total_writes;
    integer total_reads;

    // =========================================================
    // DUT
    // =========================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk   (wr_clk),
        .wr_rst_n (wr_rst_n),
        .wr_en    (wr_en),
        .data_in  (data_in),
        .full     (full),

        .rd_clk   (rd_clk),
        .rd_rst_n (rd_rst_n),
        .rd_en    (rd_en),
        .data_out (data_out),
        .empty    (empty)
    );

    // =========================================================
    // WRITE CLOCK
    // 100 MHz
    // =========================================================

    initial begin
        wr_clk = 1'b0;

        forever begin
            #5;
            wr_clk = ~wr_clk;
        end
    end

    // =========================================================
    // READ CLOCK
    // ~76.9 MHz
    // =========================================================

    initial begin
        rd_clk = 1'b0;

        forever begin
            #6.5;
            rd_clk = ~rd_clk;
        end
    end

    // =========================================================
    // RESET
    // =========================================================

    initial begin

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en   = 1'b0;
        rd_en   = 1'b0;
        data_in = '0;

        errors        = 0;
        total_writes  = 0;
        total_reads   = 0;

        expected_queue.delete();

        #40;

        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        $display("");
        $display("==================================================");
        $display("RESET RELEASED");
        $display("==================================================");

    end

    // =========================================================
    // WRITE SCOREBOARD
    //
    // A write is considered successful when:
    //
    // wr_en = 1
    // full  = 0
    //
    // This matches the DUT condition.
    // =========================================================

    always @(posedge wr_clk) begin

        if (wr_rst_n) begin

            if (wr_en && !full) begin

                expected_queue.push_back(data_in);

                total_writes = total_writes + 1;

                $display(
                    "[WRITE] time=%0t data=%08h queue_size=%0d",
                    $time,
                    data_in,
                    expected_queue.size()
                );

            end

        end

    end

    // =========================================================
    // READ SCOREBOARD
    //
    // A read is considered successful when:
    //
    // rd_en = 1
    // empty = 0
    // =========================================================

    always @(posedge rd_clk) begin

        logic [DATA_WIDTH-1:0] expected_data;

        if (rd_rst_n) begin

            if (rd_en && !empty) begin

                #1;

                if (expected_queue.size() == 0) begin

                    $error(
                        "[SCOREBOARD ERROR] FIFO read accepted but expected queue is empty. time=%0t",
                        $time
                    );

                    errors = errors + 1;

                end
                else begin

                    expected_data = expected_queue.pop_front();

                    total_reads = total_reads + 1;

                    if (data_out !== expected_data) begin

                        $error(
                            "[DATA ERROR] time=%0t expected=%08h actual=%08h",
                            $time,
                            expected_data,
                            data_out
                        );

                        errors = errors + 1;

                    end
                    else begin

                        $display(
                            "[READ ] time=%0t data=%08h queue_size=%0d",
                            $time,
                            data_out,
                            expected_queue.size()
                        );

                    end

                end

            end

        end

    end

    // =========================================================
    // WRITE TASK
    // =========================================================

    task write_data(input logic [DATA_WIDTH-1:0] value);

        begin

            @(negedge wr_clk);

            data_in = value;
            wr_en   = 1'b1;

            @(negedge wr_clk);

            wr_en = 1'b0;

        end

    endtask

    // =========================================================
    // READ TASK
    // =========================================================

    task read_data;

        begin

            @(negedge rd_clk);

            rd_en = 1'b1;

            @(negedge rd_clk);

            rd_en = 1'b0;

        end

    endtask

    // =========================================================
    // TEST 1
    // BASIC FIFO TEST
    // =========================================================

    task basic_test;

        begin

            $display("");
            $display("==================================================");
            $display("TEST 1 : BASIC FIFO");
            $display("==================================================");

            write_data(32'h0000_0001);
            write_data(32'h0000_0002);
            write_data(32'h0000_0003);
            write_data(32'h0000_0004);
            write_data(32'h0000_0005);

            // Wait for write pointer synchronization.
            repeat (6) @(posedge rd_clk);

            read_data();
            read_data();
            read_data();
            read_data();
            read_data();

            repeat (6) @(posedge rd_clk);

        end

    endtask

    // =========================================================
    // TEST 2
    // FULL TEST
    // =========================================================

    task full_test;

        integer i;

        begin

            $display("");
            $display("==================================================");
            $display("TEST 2 : FULL CONDITION");
            $display("==================================================");

            // Wait until FIFO is empty.
            repeat (10) @(posedge rd_clk);

            for (i = 0; i < DEPTH; i = i + 1) begin

                write_data(32'h1000_0000 + i);

            end

            // Wait for FULL flag.
            repeat (5) @(posedge wr_clk);

            if (full == 1'b1) begin

                $display("[PASS] FULL asserted correctly.");

            end
            else begin

                $error("[FAIL] FULL did not assert.");

                errors = errors + 1;

            end

            // Try one extra write.
            write_data(32'hDEAD_BEEF);

            repeat (3) @(posedge wr_clk);

        end

    endtask

    // =========================================================
    // TEST 3
    // EMPTY TEST
    // =========================================================

    task empty_test;

        integer i;

        begin

            $display("");
            $display("==================================================");
            $display("TEST 3 : EMPTY CONDITION");
            $display("==================================================");

            // Read all FIFO entries.
            for (i = 0; i < DEPTH; i = i + 1) begin

                read_data();

            end

            // Allow EMPTY flag to update.
            repeat (6) @(posedge rd_clk);

            if (empty == 1'b1) begin

                $display("[PASS] EMPTY asserted correctly.");

            end
            else begin

                $error("[FAIL] EMPTY did not assert.");

                errors = errors + 1;

            end

            // Try extra read.
            read_data();

            repeat (3) @(posedge rd_clk);

        end

    endtask

    // =========================================================
    // RANDOM WRITE PROCESS
    // =========================================================

    task random_write_process;

        integer i;
        logic [DATA_WIDTH-1:0] random_data;

        begin

            for (i = 0; i < 300; i = i + 1) begin

                @(negedge wr_clk);

                if ($urandom_range(0, 1) == 1) begin

                    if (!full) begin

                        random_data = $urandom();

                        data_in = random_data;
                        wr_en   = 1'b1;

                    end
                    else begin

                        wr_en = 1'b0;

                    end

                end
                else begin

                    wr_en = 1'b0;

                end

            end

            wr_en = 1'b0;

        end

    endtask

    // =========================================================
    // RANDOM READ PROCESS
    // =========================================================

    task random_read_process;

        integer i;

        begin

            for (i = 0; i < 300; i = i + 1) begin

                @(negedge rd_clk);

                if ($urandom_range(0, 1) == 1) begin

                    if (!empty) begin

                        rd_en = 1'b1;

                    end
                    else begin

                        rd_en = 1'b0;

                    end

                end
                else begin

                    rd_en = 1'b0;

                end

            end

            rd_en = 1'b0;

        end

    endtask

    // =========================================================
    // TEST 4
    // RANDOMIZED TEST
    // =========================================================

    task random_test;

        begin

            $display("");
            $display("==================================================");
            $display("TEST 4 : RANDOMIZED TRAFFIC");
            $display("==================================================");

            fork

                random_write_process();

                random_read_process();

            join

            // Stop new writes/reads.
            wr_en = 1'b0;
            rd_en = 1'b0;

            // Let remaining data be consumed.
            drain_fifo();

        end

    endtask

    // =========================================================
    // DRAIN FIFO
    //
    // Stop writes and keep reading until EMPTY.
    // =========================================================

    task drain_fifo;

        integer count;

        begin

            count = 0;

            while ((empty == 1'b0) && (count < DEPTH + 10)) begin

                read_data();

                count = count + 1;

            end

            repeat (8) @(posedge rd_clk);

        end

    endtask

    // =========================================================
    // FINAL REPORT
    // =========================================================

    task final_report;

        begin

            repeat (10) @(posedge rd_clk);

            $display("");
            $display("==================================================");
            $display("FINAL VERIFICATION REPORT");
            $display("==================================================");

            $display("Total accepted writes : %0d", total_writes);
            $display("Total accepted reads  : %0d", total_reads);
            $display("Remaining expected    : %0d", expected_queue.size());
            $display("Total errors          : %0d", errors);

            $display("==================================================");

            if ((errors == 0) && (expected_queue.size() == 0)) begin

                $display("");
                $display("********************************************");
                $display("*           ALL TESTS PASSED              *");
                $display("********************************************");
                $display("");

            end
            else begin

                $display("");
                $display("********************************************");
                $display("*         VERIFICATION FAILED              *");
                $display("********************************************");
                $display("");

            end

        end

    endtask

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================

    initial begin

        // Wait for reset release.
        wait (wr_rst_n == 1'b1);
        wait (rd_rst_n == 1'b1);

        // Allow synchronizers to initialize.
        repeat (10) @(posedge wr_clk);
        repeat (10) @(posedge rd_clk);

        basic_test();

        full_test();

        empty_test();

        random_test();

        final_report();

        #100;

        $finish;

    end

endmodule