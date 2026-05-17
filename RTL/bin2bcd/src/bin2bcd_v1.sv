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

// Algorithm reference: https://en.wikipedia.org/wiki/Double_dabble

// Custom binary to BCD conversion - aimed at the Altera Cyclone IV.
// Purpose: Driving a 4-digit 7-segment display.
// Port signals:
// 1. clock             (clk)
// 2. active-low reset  (rst_n)
// 3. input data valid  (valid_in)
// 4. binary input      (bin)
// 5. BCD output        (bcd)
// 6. output data valid (valid_out)           

// Important points about the design:
// 1. No FIFO buffers are used. Input data arrives at a significantly slower
// rate than the binary-to-BCD conversion process. Therefore, data loss can
// not occur and no "ready_out" signal is needed.
// 2. "valid_in" is a pulse that indicates the arrival of new data. For the 
// Altera Cyclone IV application, successive "valid_in" pulses are one second 
// apart. "valid_in" must be asserted for one clock cycle.
// 3. The design has a high latency as it cycles between SHIFT and ADD states
// repeatedly. 

module bin2bcd_v1(
   input  logic        clk,
   input  logic        rst_n,
   input  logic        valid_in,
   input  logic [13:0] bin,
   output logic [15:0] bcd,
   output logic        valid_out);
   
   localparam int NUM_OF_SHIFTS = 14;
   
   logic [29:0] bcd_reg;
   logic        new_bin;
   logic        valid_bcd;
   logic        add_3;
   logic [3:0]  shifts;
   
   assign bcd       = bcd_reg[29:14];
   assign valid_out = valid_bcd;
   
   always_ff @(negedge rst_n, posedge clk) begin
      if(!rst_n) begin
         bcd_reg   <= 30'b0;
         new_bin   <=  1'b0;
         valid_bcd <=  1'b0;
         add_3     <=  1'b0;
         shifts    <=  4'b0;
      end
      else begin
         if(!new_bin) begin
            if(valid_in) begin
               bcd_reg       <= 30'b0;
               bcd_reg[13:0] <= bin;
               new_bin       <= 1'b1;
               valid_bcd     <= 1'b0;
            end
         end
         else begin
            if(shifts < NUM_OF_SHIFTS) begin
               if(!add_3) begin
                  bcd_reg <= {bcd_reg[28:0], 1'b0};
                  add_3   <= 1'b1;
                  shifts  <= shifts + 1'b1;                 
               end
               else begin
                  if(bcd_reg[17:14] >= 5) bcd_reg[17:14] <= bcd_reg[17:14] + 2'd3;
                  if(bcd_reg[21:18] >= 5) bcd_reg[21:18] <= bcd_reg[21:18] + 2'd3;
                  if(bcd_reg[25:22] >= 5) bcd_reg[25:22] <= bcd_reg[25:22] + 2'd3;
                  if(bcd_reg[29:26] >= 5) bcd_reg[29:26] <= bcd_reg[29:26] + 2'd3;
                  add_3 <= 1'b0;
               end
            end
            else begin
               new_bin   <= 1'b0;
               valid_bcd <= 1'b1;
               shifts    <= 4'b0;
            end
         end
      end
   end
endmodule
