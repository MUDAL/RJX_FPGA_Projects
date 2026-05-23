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

// Custom binary to BCD conversion - Generic version
// Port signals:
// 1. clock             (clk)
// 2. active-low reset  (rst_n)
// 3. input data valid  (valid_in)
// 4. binary input      (bin)
// 5. BCD output        (bcd)
// 6. output data valid (valid_out)  

package util_pkg;
   // Brief: Determine the ceiling of log2 of an integer input.
   // Param: value - Input to the ceil(log2()) operation.
   function automatic int func_clg2(int value);
      if((value % 2) != 0) begin
         func_clg2 = $clog2(value);
      end
      else begin
         func_clg2 = $clog2(value) + 1;
      end
      return func_clg2;
   endfunction
   
   // Brief: Determine the ceiling of a ratio of two integers.
   // Param: num   - Numerator.
   // Param: denom - Denominator.
   function automatic int func_ceil(int num, int denom);
      func_ceil = (num + denom - 1) / denom;
   endfunction
endpackage

module bin2bcd_v3
   import util_pkg::*;
   #(parameter int MAX_IN = 9999)
    (clk, rst_n, valid_in, bin, bcd, valid_out);
    
   localparam int BIN_WIDTH     =  func_clg2(MAX_IN);
   localparam int BCD_DIGITS    =  func_ceil(BIN_WIDTH,3);
   localparam int BCD_WIDTH     =  4*BCD_DIGITS;   
   localparam int NUM_OF_SHIFTS =  BIN_WIDTH;
   localparam int BCD_REG_WIDTH =  BIN_WIDTH + BCD_WIDTH;   
   localparam int COUNTER_WIDTH =  func_clg2(BIN_WIDTH);   
   
   // Port signals
   input  logic                 clk;
   input  logic                 rst_n;
   input  logic                 valid_in;
   input  logic [BIN_WIDTH-1:0] bin;
   output logic [BCD_WIDTH-1:0] bcd;
   output logic                 valid_out;   
   
   // IDLE:  Default/reset state
   // SHIFT: In this state, shifts are synchronized with the clock signal.
   // ADD:   In this state, addition results have been registered and will be 
   // shifted in the next cycle. 
   typedef enum int unsigned {IDLE = 0, SHIFT, ADD} state_t;
   state_t state_reg;
   state_t state_next;
   
   logic [BCD_REG_WIDTH-1:0] bcd_reg;
   logic [BCD_REG_WIDTH-1:0] bcd_next;
   logic                     valid_reg;
   logic                     valid_next;
   logic [COUNTER_WIDTH-1:0] shifts_reg;
   logic [COUNTER_WIDTH-1:0] shifts_next;
   logic                     shift;
   logic [BCD_DIGITS-1:0]    ge5;  
   logic                     dig_ge5;  
   logic                     done;

   assign done = (shifts_reg == NUM_OF_SHIFTS);
   
   // Control signals asserted when the BCD digits are greater than
   // or equal to 5.
   always_comb begin: bcd_digits_logic  
      for(int i = 0; i < BCD_DIGITS; i++) begin
         ge5[i] = (bcd_reg[BCD_REG_WIDTH-1-(4*i) -: 4] >= 5);
      end
      dig_ge5 = |ge5;   
   end   
   
   always_comb begin: bcd_control_path
      state_next = state_reg;
      valid_next = valid_reg;
      shift      =   1'b0;
      case(state_reg)
         IDLE: begin  
            if(valid_in) begin
               state_next = SHIFT;
               valid_next = 1'b0;
            end
         end
         SHIFT: begin
            if(done) begin
               state_next = IDLE;
               valid_next = 1'b1;
            end
            else begin
               if(dig_ge5) state_next = ADD;
               else        shift      = 1'b1;
            end
         end
         ADD: begin
            state_next = SHIFT;
            shift      =  1'b1;           
         end
      endcase
   end
   
   always_comb begin: shifts_counter
      if(shift)       shifts_next =  shifts_reg + 1'b1;
      else if(done)   shifts_next = {COUNTER_WIDTH{1'b0}};
      else            shifts_next =  shifts_reg;
   end
   
   always_comb begin: bcd_data_path
      bcd_next = bcd_reg;
      if(state_reg == IDLE && valid_in) begin
         bcd_next                = {BCD_REG_WIDTH{1'b0}};
         bcd_next[BIN_WIDTH-1:0] =  bin;
      end
      else if(shift) bcd_next = {bcd_reg[BCD_REG_WIDTH-2:0], 1'b0};
      else if(state_reg == SHIFT && !done) begin
         for(int i = 0; i < BCD_DIGITS; i++) begin
            if(bcd_reg[ BCD_REG_WIDTH-1-(4*i) -: 4] >= 5) begin
               bcd_next[BCD_REG_WIDTH-1-(4*i) -: 4] = 
               bcd_reg[ BCD_REG_WIDTH-1-(4*i) -: 4] + 2'd3;
            end
         end         
      end
   end   
   
   // Top-level outputs
   assign bcd       = bcd_reg[BCD_REG_WIDTH-1:BIN_WIDTH];
   assign valid_out = valid_reg; 
   
   always_ff @(negedge rst_n, posedge clk) begin: registers
      if(!rst_n) begin
         state_reg  <=        IDLE;
         bcd_reg    <= {BCD_REG_WIDTH{1'b0}};        
         valid_reg  <=        1'b0;
         shifts_reg <= {COUNTER_WIDTH{1'b0}};
      end
      else begin
         state_reg  <= state_next;
         bcd_reg    <= bcd_next;        
         valid_reg  <= valid_next;
         shifts_reg <= shifts_next;
      end
   end
endmodule