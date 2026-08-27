// MatMul2.bsv --- a 2x2 integer matrix multiplier.
//
// This is the smoke test for Lab 0: it is small enough to read in one sitting,
// but it exercises the whole bsc flow (type-check, static elaboration, Bluesim
// codegen, C++ link) and every BSV construct the course leans on --
// Vector, FIFOF, a guarded rule, and an interface with implicit handshaking.
//
// It is also a deliberate preview.  The mini-project asks you to build a matrix
// multiply accelerator and attach it to Fife as a RISC-V extension; the datapath
// below is the seed of that unit, minus the pipelining and the ISA plumbing.

package MatMul2;

import Vector :: *;
import FIFOF  :: *;

// ================================================================
// Types
//
// N is `Integer` (compile-time) while `numN` is the same value reflected into
// the type level.  Widths and array sizes in BSV are fixed during elaboration,
// which is why the loops below unroll into pure combinational logic.

typedef 2 N;
Integer numN = valueOf (N);

typedef Int #(32)                        Elem;
typedef Vector #(N, Elem)                Row;
typedef Vector #(N, Row)                 Mat;

// ================================================================
// Interface
//
// `put` accepts a pair of matrices; `get` hands back their product.  Neither
// method carries an explicit "ready" wire: bsc derives the handshake from the
// FIFO guards, so a caller simply cannot `put` into a full input queue.

interface MatMul2_IFC;
   method Action              put (Mat a, Mat b);
   method ActionValue #(Mat)  get;
endinterface

// ================================================================
// Helpers

// Build a matrix from its elements, row-major, so the testbench reads clearly.
function Mat mkMat (Elem a00, Elem a01, Elem a10, Elem a11);
   Row r0 = cons (a00, cons (a01, nil));
   Row r1 = cons (a10, cons (a11, nil));
   return cons (r0, cons (r1, nil));
endfunction

// C = A x B, fully unrolled.  Each output element is a dot product of one row
// of A with one column of B -- N multiplies and N-1 adds of pure combinational
// logic.  Scaling N is what turns this from an expression into an architecture
// problem, and that is the subject of the mini-project.
function Mat matmul (Mat a, Mat b);
   Mat c = ?;
   for (Integer i = 0; i < numN; i = i + 1) begin
      Row row = ?;
      for (Integer j = 0; j < numN; j = j + 1) begin
	 Elem acc = 0;
	 for (Integer k = 0; k < numN; k = k + 1)
	    acc = acc + (a[i][k] * b[k][j]);
	 row[j] = acc;
      end
      c[i] = row;
   end
   return c;
endfunction

// ================================================================
// Module

(* synthesize *)
module mkMatMul2 (MatMul2_IFC);

   FIFOF #(Tuple2 #(Mat, Mat)) f_in  <- mkFIFOF;
   FIFOF #(Mat)                f_out <- mkFIFOF;

   // Fires whenever there is a pending pair and room for the result.  Both
   // conditions are implicit -- they come from `first`/`deq` and `enq`.
   rule rl_mul;
      match { .a, .b } = f_in.first;
      f_in.deq;
      f_out.enq (matmul (a, b));
   endrule

   method Action put (Mat a, Mat b);
      f_in.enq (tuple2 (a, b));
   endmethod

   method ActionValue #(Mat) get;
      f_out.deq;
      return f_out.first;
   endmethod
endmodule

// ================================================================

endpackage: MatMul2
