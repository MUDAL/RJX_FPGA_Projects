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

// Reset Domain Crossing (RDC) Testbench.

`timescale 1ns / 1ps

module rdc_tb();
   
   localparam int CLK_PERIOD = 100;
   
   logic clk      = 1'b0;
   logic rst_n_in = 1'b1;
   logic rst_n_out;
   
   initial begin: clock_gen
      forever begin
         #(CLK_PERIOD/2);
         clk <= ~clk;
      end
   end
   
   initial begin: reset_gen
      repeat(5) @(posedge clk);
      rst_n_in <= 1'b0;
      repeat(5) @(posedge clk);
      rst_n_in <= 1'b1;
      repeat(5) @(posedge clk);
   end
   
   rdc uut(.clk      (clk),
           .rst_n_in (rst_n_in),
           .rst_n_out(rst_n_out));
   
   bit rst_n_in_asserted       = 1'b0;
   bit rst_n_in_deasserted     = 1'b0;
   int rst_n_in_assert_time    =  0;
   int rst_n_in_deassert_time  =  0;
   int time_difference         =  0;
   
   initial begin: monitor
      $timeformat(-9, 0, " ns");
      
      // Testing asynchronous reset assertion
      forever begin
         @(posedge clk);
         if(rst_n_in == 1'b0 && !rst_n_in_asserted) begin
            $display("%0t | rst_n_in asserted", $time);
            rst_n_in_asserted    = 1'b1;
            rst_n_in_assert_time = $time;
         end
         
         if(rst_n_out == 1'b0 && rst_n_in_asserted) begin
            $display("%0t | rst_n_out asserted", $time);
            if($time == rst_n_in_assert_time) begin
               $display("[PASS]: rst_n_out asserted immediately as expected");
               break;
            end
            else begin
               $fatal(1, "[FAIL]: rst_n_out not asserted immediately");
            end
         end
      end
      
      // Testing synchronous reset deassertion
      forever begin
         @(posedge clk);
         if(rst_n_in == 1'b1 && !rst_n_in_deasserted) begin
            $display("%0t | rst_n_in deasserted", $time);
            rst_n_in_deasserted    = 1'b1;
            rst_n_in_deassert_time = $time;
         end
         
         if(rst_n_out == 1'b1 && rst_n_in_deasserted) begin
            $display("%0t | rst_n_out deasserted", $time);
            time_difference = $time - rst_n_in_deassert_time;
            if(time_difference == 2*CLK_PERIOD) begin
               $display("[PASS]: Output deasserted after %0d cycles, expected %0d cycles",
                       (time_difference/CLK_PERIOD), 2);
               $finish;
            end
            else begin
               $fatal(1, "[FAIL]: Output deasserted after %0d cycles, expected %0d cycles",
                     (time_difference/CLK_PERIOD), 2);
            end 
         end
      end
   end
endmodule
