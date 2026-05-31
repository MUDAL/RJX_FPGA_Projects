//  Copyright (c) 2026 Olaoluwa Raji
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

// Testbench for the Binary-to-BCD module.

// Modified by Olaoluwa Raji on 24/05/2026.
// Changes made: Accounted for reset domain crossing (RDC).

`timescale 1ns / 1ps

module bin2bcd_tb();
   // Constant
   localparam int CLK_PERIOD = 10;
   // Signals: UUT
   logic                      clk      =  1'b0;
   logic                      rst_n    =  1'b1;
   logic                      valid_in =  1'b0;
   logic [pkg::BIN_WIDTH-1:0] bin      = 14'b0;
   logic [pkg::BCD_WIDTH-1:0] bcd;
   logic                      valid_out;
   // Signals: RDC
   logic rst_n_sync = 1'b1;
   // Signals: Simulation
   logic [pkg::BIN_WIDTH-1:0] bin_val;
   logic [pkg::BCD_WIDTH-1:0] exp_val;
   logic [pkg::BCD_WIDTH-1:0] exp_queue[$]; // Queue of expected values
   logic file_end      = 1'b0;
   int   tests_sent    =  0;
   int   tests_checked =  0;
   
   initial begin: clock_gen
      forever begin
         #(CLK_PERIOD / 2);
         clk <= ~clk;
      end
   end
   
   initial begin: reset_gen
      repeat(5) @(posedge clk);
      rst_n <= 1'b0;
      repeat(5) @(posedge clk);
      rst_n <= 1'b1;
   end
   
   // Instantiate reset domain crossing module.
   rdc reset_sync(.clk       (clk),
                  .rst_n_in  (rst_n),
                  .rst_n_out (rst_n_sync));     
   
   // Read test vectors from file(s) and inject into the UUT.
   // NB: The text file should contain values from 0 to 9999.
   // $fscanf() with %d and %x format specifier for stimuli
   // and expected values, respectively. The same text file is to used.
   
   // Expected values are pushed into a queue.
   // "valid_in" is de-asserted after injecting the UUT
   // with all test stimuli. A reasonable delay is added after
   // this to simulate the requirement for the "valid_in" pulse. Ideally,
   // the pulse is 1 Hz but its frequency is increased to speed up the
   // simulation. The "valid_in" period should exceed the UUT's latency (or
   // conversion time).
   
   int fd;
   int rc;
   int eof;
   
   initial begin: stimuli
      wait(rst_n_sync == 1'b0);
      wait(rst_n_sync == 1'b1);
      fd = $fopen("../scripts/vectors.txt", "r");
      
      if(fd == 0) $fatal(1, "Failed to open vectors.txt");
      while(1) begin
         eof = $feof(fd);
         if(eof) begin
            file_end <= 1'b1;
            valid_in <= 1'b0;
            @(posedge clk);
            break;
         end
         // Read bin_val and exp_val
         rc = $fscanf(fd, "%d %x\n", bin_val, exp_val);
         valid_in   <= 1'b1;
         bin        <= bin_val;
         tests_sent <= tests_sent + 1;
         exp_queue.push_back(exp_val);
         @(posedge clk);
         valid_in   <= 1'b0;
         repeat(50) @(posedge clk);
      end
   end
   
   // UUT
   bin2bcd uut(.clk       (clk),
               .rst_n     (rst_n),
               .valid_in  (valid_in),
               .bin       (bin),
               .bcd       (bcd),
               .valid_out (valid_out));   
               
   // Monitor UUT's output and compare with expected values.
   logic [pkg::BCD_WIDTH-1:0] exp_deq;
   logic output_was_high = 1'b0;
   int   passed = 0;
   int   failed = 0;
   
   initial begin: monitor
      $timeformat(-9, 0, " ns");
      wait(rst_n_sync == 1'b0);
      wait(rst_n_sync == 1'b1);
      forever begin
         @(posedge clk);
         if(exp_queue.size()==0 && file_end && (tests_checked == tests_sent)) begin
            $display("%0t | SENT: %4d tests, CHECKED: %4d tests",
                     $time,
                     tests_sent,
                     tests_checked);
            $display("%0t | PASSED: %4d, FAILED: %4d",$time,passed,failed);
            $fclose(fd);
            $finish;
         end
         
         if(valid_out && !output_was_high) begin
            output_was_high = 1'b1;
            if(exp_queue.size()==0) $fatal("Can't pop an empty queue!!!");
            else begin
               exp_deq = exp_queue.pop_front();
               if(bcd == exp_deq) begin
                  $display("%0t | PASS - Expected: %x, Got: %x",$time,exp_deq,bcd);
                  passed = passed + 1;
               end
               else begin
                  $display("%0t | FAIL - Expected: %x, Got: %x",$time,exp_deq,bcd);
                  failed = failed + 1;
               end
               tests_checked = tests_checked + 1;
            end
         end
         else if(!valid_out && output_was_high) output_was_high = 1'b0;
      end
   end

endmodule
