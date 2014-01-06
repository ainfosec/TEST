#ifndef __SOFT_STACK_STACK
#define __SOFT_STACK_STACK

#include "main.h"
#include "isa.h"

/**
 * An Instruction stores a single binary instruction to be executed in the
 *  ARM-Lite processor.
 */
typedef struct _Instruction
{
  /** this Instruction's unique address */
  unsigned address;

  /** this Instruction's instruction binary */
  unsigned binary;

  /** a decoded opcode for this instruction's */
  ThumbISA opcode;

  /** the previous Instruction or NULL */
  struct _Instruction *prev;

  /** the next Instruction or NULL */
  struct _Instruction *next;

  /**
   * Destructor
   *
   * @return NULL
   */
  struct _Instruction * (*free)(struct _Instruction *self);

} Instruction;

/**
 * A Stack comprises many Instructions, a Program Counter (PC), a
 *  a Link Register (LR), and support for adding, removing, and retrieving
 *  the contained Instructions.
 */
typedef struct _Stack
{
  /** the number of Instructions in this Stack */
  unsigned (*size)();

  /** the Program Counter for this Stack (address of the current instruction) */
  unsigned (*PC)();

  /** the Link Register for this Stack (stored address) */
  unsigned (*LR)();

  /** the root of the linked Instruction list */
  Instruction *trunk;

  /**
   * Add a single Instruction to this Stack
   *
   * @param binary binary to store in a new Instruction, which is
   *               added to this stack at the location stored in the PC
   * @return this Stack, or NULL on failure after destroying this stack
   **/
  struct _Stack * (*push)(struct _Stack *self, unsigned binary);

  /**
   * Returns the next Instruction binary to execute, and removes the
   *  corresponding Instruction from this Stack
   *
   * @param popped the removed Instruction will be copied into this buffer,
   *               passed by reference
   * @return this Stack, or NULL on failure after destroying this stack
   **/
  struct _Stack * (*pop) (struct _Stack *self, Instruction **popped);

  /**
   * Returns a desired Instruction from the Stack
   *
   * @param address address matching that in the desired Instruction
   * @return the Instruction at the given address
   */
  Instruction * (*get)(struct _Stack *self, unsigned address);

  /**
   * Moves the PC to the provided address, and returns the binary
   *  for the Instruction at that address
   *
   * @param address an absolute address, relative to the bottom of the Stack
   * @return the desired binary to execute, or 0x0000DEXX ("unused")
   *         if no Instruction is at the provided address
   */
  unsigned (*jump)(struct _Stack *self, unsigned address);

  /**
   * Sets the LR to the value stored in the PC, then calls the jump method
   *  with the provided address
   *
   * @see Instruction::jump
   */
  unsigned (*jumpAndLink)(struct _Stack *self, unsigned address);

  /**
   * Calls the jump method with the Link Register value as the provided address
   *
   * @see Instruction::jump
   */
  unsigned (*jumpAndReturn)(struct _Stack *self);

  /**
   * Destructor
   *
   * @return NULL
   */
  struct _Stack * (*free)(struct _Stack *self);

} Stack;

/**
 * Constructor
 *
 * @param binary raw binary to store in this Instruction
 */
Instruction * newInstruction(unsigned binary);

/**
 * Constructor
 *
 * @param bytes raw instruction hex to break up into instructions
 * @param num_instructions the number of hexadecimal instructions,
 *        should be equal to half the number of bytes sent in.
 */
Stack * newStack(unsigned char *bytes, size_t num_instructions);

#endif /* __SOFT_STACK_STACK */
