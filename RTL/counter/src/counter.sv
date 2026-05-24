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

// Generic Counter Module.

// Port signals:
// 1. clock             (clk)
// 2. active-low reset  (rst_n)
// 3. enable
// 4. clear
// 5. count
// 6. done

module counter
   #(parameter int WIDTH = 4,
     parameter int MAX   = 2**WIDTH)
    (input  logic             clk,
     input  logic             rst_n,
     input  logic             enable,
     input  logic             clear,
     output logic [WIDTH-1:0] count,
     output logic             done);
   
   logic [WIDTH-1:0] count_reg;
   logic [WIDTH-1:0] count_next;
   
   // Top-level outputs
   assign count = count_reg;
   assign done  = (count_reg == MAX - 1);
   
   always_comb begin: data_path
      count_next = count_reg;
      if(enable) begin
         if(count_reg == MAX - 1) count_next = {WIDTH{1'b0}}; 
         else                     count_next = count_reg + 1'b1;
      end
      else if(clear) count_next = {WIDTH{1'b0}};         
   end
   
   always_ff @(negedge rst_n, posedge clk) begin: registers
      if(!rst_n) count_reg <= {WIDTH{1'b0}}; 
      else       count_reg <= count_next;
   end
endmodule

