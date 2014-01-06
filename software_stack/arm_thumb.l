%{
  #include <stdlib.h>
  void yyerror(char *);
  #include "y.tab.h"
%}

%%

  /* TODO: this is just here for structure; ARM Thumb compiler stuff here */
  /* variables */
[a-z]  { yylval = *yytext - 'a'; return INTEGER; }
[A-Z]  { yylval = *yytext - 'A'; return INTEGER; }

  /* numbers */
[0-9]+    { yylval = atoi(yytext); return INTEGER; }

  /* operation, including enter as equals */
[-+*/=()\n]    { return *yytext; }

  /* skip whitespace */
[ \t]     { ; }

  /* invalid input */
.         { yyerror("invalid character"); }

%%

/** */
int yywrap(void)
{
  return 1;
}
