#include "stack.h"
#include "isa.h"

/* method forward decls */
unsigned Stack_PC();
unsigned Stack_LR();
unsigned Stack_size();
Stack * Stack_push(Stack *self, unsigned instruction);
Stack * Stack_pop(Stack *self, Instruction **popped);
Instruction * Stack_get(Stack *self, unsigned address);
unsigned Stack_jump(Stack *self, unsigned address);
unsigned Stack_jumpAndLink(Stack *self, unsigned address);
Instruction * Instruction_free(Instruction *self);
Stack * Stack_free(Stack *self);

/**
 * Iterable array containing every opcode
 */
ThumbISA allInstructions[64] = {
  ADC_RGM_RGD,      ADD_HF2_RGM_RGD,   ADD_IM3_RGN_RGD,  ADD_RGD_IM8,
  ADD_RGM_RGN_RGD,  ADDPC_RGD_IM8,     ADDSP_RGD_IM8,    AND_RGM_RGD,
  ASR_IM5_RGM_RGD,  ASR_RGS_RGD,       B_IM8,            BCOND_IM8,
  BIC_RGN_RGM,      BKPT_IM8,          BL_IM8,           BLX_HF1_RGM_C30,
  BLX_IM8,          BLXH_IM8,          BX_HF1_RGM_C30,   CMN_RGN_RGM,
  CMP_HF2_RGN_RGM,  CMP_RGN_IM8,       CMP_RGN_RGM,      EOR_RGM_RGD,
  LDMIA_RGN_RL8,    LDR_IM5_RGN_RGD,   LDR_RGM_RGN_RGD,  LDRB_IM5_RGN_RGD,
  LDRB_RGM_RGN_RGD, LDRH_IM5_RGN_RGD,  LDRH_RGM_RGN_RGD, LDRPC_RGD_IM8,
  LDRSB_RGM_RGN_RGD,LDRSH_RGM_RGN_RGD, LDRSP_RGD_IM8,    LSL_IM5_RGM_RGD,
  LSL_RGS_RGD,      LSR_IM5_RGM_RGD,   LSR_RGS_RGD,      MOV_HF2_RGM_RGD,
  MOV_RGD_IM8,      MUL_RGM_RGD,       MVN_RGM_RGD,      NEG_RGM_RGD,
  ORR_RGM_RGD,      POP_HF1_IM8,       PUSH_HF1_IM8,     ROR_RGS_RGD,
  SBC_RGM_RGD,      STMIA_RGN_IM8,     STR_IM5_RGN_RGD,  STR_RGM_RGN_RGD,
  STRB_IM5_RGN_RGD, STRB_RGM_RGN_RGD,  STRH_IM5_RGN_RGD, STRH_RGM_RGN_RGD,
  STRSP_RGD_IM8,    SUB_C11_IM7,       SUB_IM3_RGN_RGD,  SUB_RGM_IM8,
  SUB_RGM_RGN_RGD,  SWI_IM8,           TST_RGN_RGM,      UNUSED_IM8
};

/* private storage for the node size, 'grow' can be used to change +/- */
static unsigned Stack_changeSize(char grow)
{
  static unsigned size = 0;

  size += grow;

  return size;
}

/* private storage for the PC pointer size, 'move' can be used to change +/- */
static unsigned Stack_movePC(char move)
{
  static unsigned PC = 0;

  PC += move;

  return PC;
}

/* private storage for the LR pointer size, 'move' can be used to change +/- */
static unsigned Stack_moveLR(char move)
{
  static unsigned LR = 0;

  LR += move;

  return LR;
}

/* constructor */
Instruction * newInstruction(unsigned binary)
{
  Instruction *self = (Instruction *) malloc(sizeof(Instruction));
  int i;

  /* out of memory */
  if (! self)
  {
    return NULL;
  }

  /* zero */
  memset(self, 0, sizeof(Instruction));

  /* increase the size of the stack by 1 */
  Stack_changeSize(1);

  /* bind instruction */
  self->binary = binary;

  /* get the instruction opcode */
  self->opcode = UNUSED_IM8;
  for (i = 0; i < 64; i++)
  {
    if (CODE_MATCHES(binary, allInstructions[i]))
    {
      self->opcode = allInstructions[i];
    }
  }

  /* bind methods */
  self->free        = Instruction_free;

  return self;
}

/* constructor */
Stack * newStack(unsigned char *bytes, size_t num_instructions)
{
  Stack *self = (Stack *) malloc(sizeof(Stack));
  unsigned binary;
  unsigned char *byteptr = bytes;

  /* out of memory */
  if (! self)
  {
    return NULL;
  }

  /* zero */
  memset(self, 0, sizeof(Instruction));

  /* bind methods */
  self->PC          = Stack_PC;
  self->LR          = Stack_LR;
  self->size        = Stack_size;
  self->push        = Stack_push;
  self->pop         = Stack_pop;
  self->get         = Stack_get;
  self->jump        = Stack_jump;
  self->jumpAndLink = Stack_jumpAndLink;
  self->free        = Stack_free;

  /* set up the linked list */
  if (bytes)
  {
    do
    {
      /* grab next binary */
      binary = (byteptr[0] << 0x0) + (byteptr[1] << 0x8);

      /* push the new instruction onto the list */
      if (
             ( (  self->trunk) && (! (self->push(self, binary))            ) )
          || ( (! self->trunk) && (! (self->trunk = newInstruction(binary))) )
          )
      {
        self->free(self);
        return NULL;
      }

    } while ( (byteptr += 2) < (bytes + 2 * num_instructions) );
  }

  return self;
}

/* program counter pointer */
unsigned Stack_PC()
{
  return Stack_movePC(0);
}

/* link register pointer */
unsigned Stack_LR()
{
  return Stack_moveLR(0);
}

/* current size of the stack */
unsigned Stack_size()
{
  return Stack_changeSize(0);
}

/* add a new node to the stack */
Stack * Stack_push(Stack *self, unsigned binary)
{
  Instruction *found = self ? self->get(self, Stack_movePC(0)) : NULL,
              *new = found ? newInstruction(binary) : NULL,
              *last = new, *first = new;

  /* relink */
  if (new)
  {
    /* link the new node in */
    if ( (new->prev = found->prev) )
    {
      (new->prev)->next = new;
    }
    if ( ((new->next = found)->next) )
    {
      (new->next)->prev = new;
    }

    /* reindex */
    while ((last = last->next))
    {
      last->address++;
    }

    /* find the head of the stack */
    while (first->prev && (first = first->prev));
    self->trunk = first;
  }

  /* stack size automatically incremented when we create a new node */

  /* destroy this stack if there were problems */
  return new ? self : self->free(self);
}

/* Return the next Stack in the stack */
Stack * Stack_pop(Stack *self, Instruction **popped)
{
  Instruction *found = self ? self->get(self, Stack_PC(0)) : NULL,
              *last = found, *first = found->next;

  /* relink */
  *popped = NULL;
  if (found)
  {

    /* reindex */
    while ((last = last->next))
    {
      last->address--;
    }

    /* unlink the popped node */
    if (found->prev)
    {
      (found->prev)->next = found->next;
    }
    if (found->next)
    {
      (found->next)->prev = found->prev;
    }
    found->prev = found->next = NULL;

    /* return the popped node */
    *popped = found;

    /* find the head of the stack */
    while (first && first->prev && (first = first->prev));
    self->trunk = first;
  }

  /* shrink the stack size by 1 */
  Stack_size(-1);

  /* destroy this stack if there were problems (or it's empty) */
  return first ? self : self->free(self);
}

/* return a node at a given address */
Instruction * Stack_get(Stack *self, unsigned address)
{
  Instruction *cur = NULL;

  while ((cur = cur ? cur->next : self->trunk))
  {
    if (cur->address == address)
    {
      return cur;
    }
  }

  return NULL;
}

/* Stack::get + modify PC, and just return the instruction */
unsigned Stack_jump(Stack *self, unsigned address)
{
  Instruction *cur = self ? self->get(self, address) : NULL;

  if (cur)
  {
    Stack_movePC(address - Stack_movePC(0));
    return cur->binary;
  }

  /* 0xDEXX is the unused instruction, return if something went wrong */
  return 0x0000DEFF;
}

/* Stack::jump + modify LR */
unsigned Stack_jumpAndLink(Stack *self, unsigned address)
{
  unsigned old_PC = Stack_movePC(0), new_instruction;

  if ((new_instruction = self->jump(self, address)) != 0x0000DEFF)
  {
    Stack_LR(old_PC - Stack_moveLR(0));
  }

  return new_instruction;
}

/* destructor */
Stack * Stack_free(Stack *self)
{
  Instruction *cur = self ? self->trunk : NULL;

  /* if an instruction list is present, free it first */
  if (cur)
  {

    /* make sure we've rewound to the head */
    while (cur->prev && (cur = cur->prev));

    /* recur down the Instruction list */
    if ((self->trunk = cur->next))
    {
      (self->trunk)->prev = NULL;
      self->free(self);
    }

    /* destroy this Instruction */
    cur->free(cur);
    return NULL;
  }

  /* the instruction list has been freed */
  free(self);
  return NULL;
}

/* destructor */
Instruction * Instruction_free(Instruction *self)
{
  free(self);
  return NULL;
}
