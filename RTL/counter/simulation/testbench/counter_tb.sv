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

// TO-DO:
// 1. Test for counter "enable". Monitor "count".
// 2. Test for "clear". Check if "count = 0" one cycle after "clear = 1"
// 3. Test for "done".  Check if "done = 1" (for one cycle) when "count" 
// reaches limit and resets. 

`timescale 1ns / 1ps

module counter_tb();
   
   localparam int CLK_PERIOD = 100;
   localparam int WIDTH = 4;
   // Signals: UUT
   logic             clk    = 1'b0;
   logic             rst_n  = 1'b1;
   logic             enable = 1'b0;
   logic             clear  = 1'b0;
   logic [WIDTH-1:0] count;
   logic             done;
   
   initial begin: clock_gen
      forever begin
         #(CLK_PERIOD/2);
         clk <= ~clk;
      end
   end
   
   initial begin: reset_gen
      repeat(5) @(posedge clk);
      rst_n <= 1'b0;
      repeat(5) @(posedge clk);
      rst_n <= 1'b1;
      repeat(5) @(posedge clk);
   end
   
   initial begin: stimuli
      wait(rst_n == 0);
      wait(rst_n == 1);
      // Enough time for rst_n to be safely de-asserted
      repeat(10) @(posedge clk); 
      
      forever begin
      end
   end
   
   // UUT
   counter #(.WIDTH  (WIDTH)) uut
            (.clk    (clk),
             .rst_n  (rst_n),
             .enable (enable),
             .clear  (clear),
             .count  (count),
             .done   (done));
   
   initial begin: monitor
      $timeformat(-9, 0, " ns");
      wait(rst_n == 0);
      wait(rst_n == 1);
      // Enough time for rst_n to be safely de-asserted
      repeat(10) @(posedge clk); 
      
      forever begin
      end
   end
endmodule
