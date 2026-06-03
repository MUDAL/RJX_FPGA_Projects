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

// Counter Testbench.

`timescale 1ns / 1ps

module counter_tb();
   
   localparam int CLK_PERIOD = 10;
   localparam int WIDTH      = 4;
   localparam int MAX_CYCLES = 2**WIDTH;
   // Signals: UUT
   logic             clk    = 1'b0;
   logic             rst_n  = 1'b1;
   logic             enable = 1'b0;
   logic             clear  = 1'b0;
   logic [WIDTH-1:0] count;
   logic             done;
   // Signals: RDC
   logic rst_n_sync = 1'b1;   
   
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
   
   localparam int CYCLES_BEFORE_CLEAR = 5; 
   int time_enabled = 0;
   
   initial begin: stimuli
      $display("%0t | Counter should count %0d cycles",$time, MAX_CYCLES);
      wait(rst_n_sync == 1'b0);
      wait(rst_n_sync == 1'b1);
      
      // Test 1: Counter enable
      $display("%0t | Test 1: \"counter enable\"",$time);
      @(posedge clk);
      $display("%0t | Asserting the \"enable\" input",$time);
      enable       <= 1'b1;
      time_enabled  = $time;
      
      forever begin
         @(posedge clk);
         if(done) begin
            $display("%0t | De-asserting the \"enable\" input",$time);
            enable <= 1'b0;
            break;
         end
      end
      
      // Test 2: Counter clear
      $display("%0t | Test 2: clearing after %0d cycles since asserting \"enable\"",
               $time, CYCLES_BEFORE_CLEAR + 1);
      @(posedge clk);
      $display("%0t | Asserting the \"enable\" input",$time);
      enable       <= 1'b1;
      time_enabled  = $time;
      repeat(CYCLES_BEFORE_CLEAR) @(posedge clk);
      $display("%0t | Asserting the \"clear\" input",$time);
      clear <= 1'b1;
      @(posedge clk);
   end
   
   // UUT
   counter #(.WIDTH  (WIDTH)) uut
            (.clk    (clk),
             .rst_n  (rst_n_sync),
             .enable (enable),
             .clear  (clear),
             .count  (count),
             .done   (done));
   
   int cycles_counted  = 0;
   bit test1_completed = 1'b0;
   
   initial begin: monitor
      $timeformat(-9, 0, " ns");
      wait(rst_n_sync == 1'b0);
      wait(rst_n_sync == 1'b1);
      
      // Test 1: Monitoring counter enable
      forever begin
         @(posedge clk);
         if(done && !test1_completed) begin
            cycles_counted = ($time - time_enabled) / CLK_PERIOD;
            if(cycles_counted == MAX_CYCLES) begin
               $display("[PASS]: Counter done after %0d cycles, expected %0d cycles", 
                        cycles_counted, MAX_CYCLES);
               test1_completed = 1'b1;
               break;
            end
            else begin
               $fatal(1, "[FAIL]: Counter done after %0d cycles, expected %0d cycles", 
                      cycles_counted, MAX_CYCLES);          
            end
         end
      end
      
      // Test 2: Monitoring counter output upon clearing
      // Due to delta cycle problems when sampling on the rising edge of clk,
      // I decided to sample on the falling edge. Another approach to resolving
      // the issue is to wait for a rising edge and introduce a small delay
      // (e.g. 1ps) after the rising edge.
      forever begin
         @(negedge clk);
         if(clear == 1'b1 && count == {WIDTH{1'b0}}) begin
            cycles_counted = ($time - time_enabled) / CLK_PERIOD;
            if(cycles_counted == (CYCLES_BEFORE_CLEAR + 1)) begin
               $display("[PASS]: Counter cleared %0d cycles after asserting \"enable\", expected %0d cycles", 
                        cycles_counted, (CYCLES_BEFORE_CLEAR + 1));
               $finish;
            end
            else begin
               $fatal(1, "[FAIL]: Counter cleared %0d cycles after asserting \"enable\", expected %0d cycles", 
                      cycles_counted, (CYCLES_BEFORE_CLEAR + 1));           
            end
         end  
      end
   end
endmodule
