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

// Binary-to-BCD module.

// Algorithm reference: https://en.wikipedia.org/wiki/Double_dabble

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
// 3. "valid_out" indicates a valid BCD output. Once it is asserted, it stays 
// asserted until a new valid input data arrives.

module bin2bcd
   #(parameter int    BIN_WIDTH  = 32,
     parameter int    BCD_WIDTH  = 4*pkg::ceil(BIN_WIDTH,3))
    (input     logic                 clk,
     input     logic                 rst_n,
     input     logic                 valid_in,
     input     logic [BIN_WIDTH-1:0] bin,
     output    logic [BCD_WIDTH-1:0] bcd,
     output    logic                 valid_out);
        
   localparam int NUM_OF_SHIFTS =  BIN_WIDTH;
   localparam int BCD_REG_WIDTH =  BIN_WIDTH + BCD_WIDTH;   
   localparam int COUNTER_WIDTH =  pkg::clog2(BIN_WIDTH);     
   
   // IDLE:       Default/reset state
   // SHIFT_SYNC: Shifts are synchronized with the clock signal.
   // ADD_SYNC:   Addition results are synchronized with the clock signal 
   // and will be shifted in the next cycle. 
   typedef enum int unsigned {IDLE = 0, SHIFT_SYNC, ADD_SYNC} state_t;
   state_t state_reg;
   state_t state_next;
   
   logic [BCD_REG_WIDTH-1:0] bcd_reg;
   logic [BCD_REG_WIDTH-1:0] bcd_next;
   logic                     valid_reg;
   logic                     valid_next;
   logic [COUNTER_WIDTH-1:0] shifts_count;
   logic                     shift;
   logic [BCD_WIDTH/4-1:0]   ge5;
   logic                     dig_ge5;  
   logic                     done;
     
   assign done = (shifts_count == NUM_OF_SHIFTS);
   
   // Control signals asserted when the BCD digits are greater than
   // or equal to 5.
   always_comb begin: bcd_digits_logic  
      for(int i = 0; i < BCD_WIDTH/4; i++) begin
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
               state_next = SHIFT_SYNC;
               valid_next =   1'b0;
            end
         end
         SHIFT_SYNC: begin
            if(done) begin
               state_next = IDLE;
               valid_next = 1'b1;
            end
            else begin
               if(dig_ge5) state_next = ADD_SYNC;
               else        shift      =   1'b1;
            end
         end
         ADD_SYNC: begin
            state_next = SHIFT_SYNC;
            shift      =   1'b1;           
         end
      endcase
   end
   
   // Instantiate counter to count the number of shifts
   counter #(.WIDTH  (COUNTER_WIDTH)) shifts_counter
            (.clk    (clk),
             .rst_n  (rst_n),
             .enable (shift),
             .clear  (done),
             .count  (shifts_count));
   
   always_comb begin: bcd_data_path
      bcd_next = bcd_reg;
      if(state_reg == IDLE && valid_in) begin
         bcd_next                = {BCD_REG_WIDTH{1'b0}};
         bcd_next[BIN_WIDTH-1:0] =  bin;
      end
      else if(shift) bcd_next = {bcd_reg[BCD_REG_WIDTH-2:0], 1'b0};
      else if(state_reg == SHIFT_SYNC && !done) begin
         for(int i = 0; i < BCD_WIDTH/4; i++) begin
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
      end
      else begin
         state_reg  <= state_next;
         bcd_reg    <= bcd_next;        
         valid_reg  <= valid_next;
      end
   end
endmodule 
