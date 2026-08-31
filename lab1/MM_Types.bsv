// MM_Types.bsv --- the contract between your unit and the harness.
//
// DO NOT EDIT for submission.  The harness compiles against this file, so any
// change here will fail to build against the grading harness even if it works
// locally.  You are free to edit it while exploring other shapes (§8 of the
// spec) -- just put it back.
//
// Everything moves in 32-bit words, because that is what one RISC-V register
// holds and this unit becomes a RISC-V instruction in Lab 2.

package MM_Types;

import Vector :: *;

// ================================================================
// Shape
//
//     C[M][N]  +=  A[M][K] * B[K][N]
//
// The submitted configuration.  W_ELEM = 8 makes one row of A and one row of B
// exactly 32 bits, so each is a single load.  A row of C is not, because the
// accumulator has to be wider than the operands -- see §3 of the spec.

typedef 4   M_DIM;
typedef 4   K_DIM;
typedef 4   N_DIM;
typedef 8   W_ELEM;    // bits per element of A and B
typedef 32  W_ACC;     // bits per element of C

Integer m_dim  = valueOf (M_DIM);
Integer k_dim  = valueOf (K_DIM);
Integer n_dim  = valueOf (N_DIM);
Integer w_elem = valueOf (W_ELEM);
Integer w_acc  = valueOf (W_ACC);

typedef Int #(W_ELEM)  Elem;
typedef Int #(W_ACC)   Acc;

typedef Vector #(M_DIM, Vector #(K_DIM, Elem))  A_Mat;
typedef Vector #(K_DIM, Vector #(N_DIM, Elem))  B_Mat;
typedef Vector #(M_DIM, Vector #(N_DIM, Acc))   C_Mat;

// ---- How many 32-bit words each row takes.
//
// These are the numbers the whole cost model rests on.  Work them out for the
// submitted shape before you start; they explain where the cycles go.
Integer elems_per_word = 32 / valueOf (W_ELEM);
Integer accs_per_word  = 32 / valueOf (W_ACC);

Integer words_per_a_row = (k_dim + elems_per_word - 1) / elems_per_word;
Integer words_per_b_row = (n_dim + elems_per_word - 1) / elems_per_word;
Integer words_per_c_row = (n_dim + accs_per_word  - 1) / accs_per_word;

// ================================================================
// Requests
//
// One request carries at most one 32-bit word in and returns at most one out.
// That is not an arbitrary restriction: in Lab 2 each of these becomes a single
// RISC-V instruction, where the word in is `rs1`, the word out is `rd`, and
// `row`/`chunk` come from the immediate field.

// A 32-bit slice of one row of A or B.
//   row   : which row
//   chunk : which 32-bit slice of that row (0 when a row fits in one word)
//   word  : ELEMS_PER_WORD elements, ELEMENT 0 IN THE LOW-ORDER BITS
typedef struct {
   Bit #(8)   row;
   Bit #(8)   chunk;
   Bit #(32)  word;
} MM_Wr deriving (Bits, FShow);

// A 32-bit slice of one row of C.
typedef struct {
   Bit #(8)  row;
   Bit #(8)  chunk;
} MM_Rd deriving (Bits, FShow);

typedef union tagged {
   MM_Wr  LoadA;    // write a slice of A
   MM_Wr  LoadB;    // write a slice of B
   void   Mul;      // C += A * B
   MM_Rd  ReadC;    // read a slice of C, AND ZERO WHAT IT RETURNS
} MM_Req deriving (Bits, FShow);

// Every request returns exactly one response, in order.  Only ReadC carries a
// value; the others respond so that the response stream stays in lockstep with
// the request stream.  Lab 2 depends on that.
typedef struct {
   Bool       has_value;
   Bit #(32)  value;
} MM_Rsp deriving (Bits, FShow);

MM_Rsp mm_rsp_none = MM_Rsp {has_value: False, value: 0};

function MM_Rsp mm_rsp_value (Bit #(32) v);
   return MM_Rsp {has_value: True, value: v};
endfunction

// ================================================================
// The interface you implement
//
// Guarded methods: `req` blocks when you cannot accept, `rsp` blocks when you
// have nothing to give.  The harness relies on that -- do not add explicit
// ready/valid signals.

interface MatMul_IFC;
   method Action                 req (MM_Req r);
   method ActionValue #(MM_Rsp)  rsp;
endinterface

endpackage: MM_Types
