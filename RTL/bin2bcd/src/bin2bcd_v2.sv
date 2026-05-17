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
// 3. The design eliminates the unnecessary latency after shifting and adding.
// Has the lowest overall latency. A finite state machine (FSM) with logically
// separated sequential and combinational logic is used. 

module bin2bcd_v2(
   input  logic        clk,
   input  logic        rst_n,
   input  logic        valid_in,
   input  logic [13:0] bin,
   output logic [15:0] bcd,
   output logic        valid_out);
   
   localparam int NUM_OF_SHIFTS = 14;
   
   // IDLE:  Default/reset state
   // SHIFT: In this state, shifts are synchronized with the clock signal.
   // ADD:   In this state, addition results have been registered and will be 
   // shifted in the next cycle. 
   typedef enum int unsigned {IDLE = 0, SHIFT, ADD} state_t;
   state_t state_reg;
   state_t state_next;
   
   logic [29:0] bcd_reg;
   logic [29:0] bcd_next;
   logic        valid_reg;
   logic        valid_next;
   logic  [3:0] shifts_reg;
   logic  [3:0] shifts_next;
   logic        shift;
   logic        dig0_ge5; // Digit 0 greater than or equal to 5
   logic        dig1_ge5; // Digit 1 greater than or equal to 5
   logic        dig2_ge5; // Digit 2 greater than or equal to 5
   logic        dig3_ge5; // Digit 3 greater than or equal to 5
   logic        dig_ge5;  // Combination of digits greater than or equal to 5
   logic        done;
   
   // Control signals asserted when the BCD digits are greater than
   // or equal to 5.
   assign dig0_ge5 = (bcd_reg[17:14] >= 5);
   assign dig1_ge5 = (bcd_reg[21:18] >= 5);
   assign dig2_ge5 = (bcd_reg[25:22] >= 5);
   assign dig3_ge5 = (bcd_reg[29:26] >= 5);
   assign dig_ge5  = (dig0_ge5 | dig1_ge5 | dig2_ge5 | dig3_ge5);
   
   assign done = (shifts_reg == NUM_OF_SHIFTS);
   
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
      if(shift)       shifts_next = shifts_reg + 1'b1;
      else if(done)   shifts_next =    4'b0;
      else            shifts_next = shifts_reg;
   end
   
   always_comb begin: bcd_data_path
      bcd_next = bcd_reg;
      if(state_reg == IDLE && valid_in) begin
         bcd_next       = 30'b0;
         bcd_next[13:0] =   bin;
      end
      else if(shift) bcd_next = {bcd_reg[28:0], 1'b0};
      else if(state_reg == SHIFT && !done) begin
         if(dig0_ge5) bcd_next[17:14] = bcd_reg[17:14] + 2'd3;
         if(dig1_ge5) bcd_next[21:18] = bcd_reg[21:18] + 2'd3;
         if(dig2_ge5) bcd_next[25:22] = bcd_reg[25:22] + 2'd3;
         if(dig3_ge5) bcd_next[29:26] = bcd_reg[29:26] + 2'd3;     
      end
   end   
   
   // Top-level outputs
   assign bcd       = bcd_reg[29:14];
   assign valid_out = valid_reg; 
   
   always_ff @(negedge rst_n, posedge clk) begin: registers
      if(!rst_n) begin
         state_reg  <=  IDLE;
         bcd_reg    <= 30'b0;        
         valid_reg  <=  1'b0;
         shifts_reg <=  4'b0;
      end
      else begin
         state_reg  <= state_next;
         bcd_reg    <= bcd_next;        
         valid_reg  <= valid_next;
         shifts_reg <= shifts_next;
      end
   end
endmodule
