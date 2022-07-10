%{

#define YYSTYPE SymbolInfo*

#include<iostream>
#include<cstdlib>
#include<cstring>
#include<cmath>
#include<fstream>
#include "1805001_SymbolInfo.h"
#include "1805001_SymbolTable.h"

using namespace std;

int yyparse(void);
int yylex(void);
extern FILE *yyin;

int lineCount=1;
int errorCount=0;

ofstream logFile,errorFile;

SymbolTable *symbolTable;

const string GROUP_VARIABLE="var";
const string GROUP_FUNCTION_DECLARATION="func_dec";
const string GROUP_FUNCTION_DEFINITION="func_def";
const string GROUP_ARRAY="array";

const string VARIANT_INT="int";
const string VARIANT_FLOAT="float";
const string VARIANT_VOID="void";
const string VARIANT_UNDEFINED="undefined";

string funcion_retyrn_type;

void yyerror(char *s)
{
	//write your code
}

void log(string rule,SymbolInfo *symbolInfo){
	logFile<<"Line "<<lineCount<<": "<<symbolInfo->getType()<<" : "<<rule<<endl<<endl<<symbolInfo->getName()<<endl<<endl;
}

void insertVariablesToTable(SymbolInfo *type,vector<SymbolInfo*> symbols,string code){
	for(int i=0;i<symbols.size();i++){
		SymbolInfo *newSymbol=new SymbolInfo(symbols[i]->getName(),"ID");
		newSymbol->setVariant(type->getName());
		newSymbol->setGroup(symbols[i]->getGroup());
		bool isInserted=symbolTable->insertSymbol(newSymbol);
		if(!isInserted){
			logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<newSymbol->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<newSymbol->getName()<<endl<<endl;
			errorCount++;
		}
	}

}

void insertFunctionDeclarationToTable(SymbolInfo *type,SymbolInfo *funcId,vector<SymbolInfo*> params,string code){
	SymbolInfo *funcSymbol=new SymbolInfo(funcId->getName(),"ID");
	funcSymbol->setVariant(type->getName());
	funcSymbol->setGroup(GROUP_FUNCTION_DECLARATION);
	for(int i=0;i<params.size();i++){
		SymbolInfo *newParam=new SymbolInfo(params[i]->getName(),"ID");
		newParam->setVariant(params[i]->getVariant());
		newParam->setGroup(params[i]->getGroup());
		funcSymbol->addChildSymbol(newParam);
	}
	bool isInserted=symbolTable->insertSymbol(funcSymbol);
	if(!isInserted){
		logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<funcSymbol->getName()<<endl<<endl<<code<<endl<<endl;
		errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<funcSymbol->getName()<<endl<<endl;
		errorCount++;
	}
}


void insertFunctionDefinitionToTable(SymbolInfo *type,SymbolInfo *funcId,vector<SymbolInfo*> params,string code){
	logFile<<symbolTable->printAllScopes();
	symbolTable->exitScope();
	SymbolInfo *funcSymbol=new SymbolInfo(funcId->getName(),"ID");
	funcSymbol->setVariant(type->getName());
	funcSymbol->setGroup(GROUP_FUNCTION_DEFINITION);
	for(int i=0;i<params.size();i++){
		SymbolInfo *newParam=new SymbolInfo(params[i]->getName(),"ID");
		newParam->setVariant(params[i]->getVariant());
		newParam->setGroup(params[i]->getGroup());
		funcSymbol->addChildSymbol(newParam);
	}
	SymbolInfo *foundSymbol=symbolTable->lookup(funcId->getName());
	if(foundSymbol==NULL)
		symbolTable->insertSymbol(funcSymbol);
	else if(foundSymbol->getGroup().compare(GROUP_FUNCTION_DECLARATION)==0){
		if(foundSymbol->getVariant().compare(type->getName())!=0){
			logFile<<"Error at line "<<lineCount<<": Return type mismatch with function declaration in function "<<funcSymbol->getName()<<endl<<endl<<code<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Return type mismatch with function declaration in function "<<funcSymbol->getName()<<endl<<endl;
			errorCount++;
		}
		if(params.size()!=foundSymbol->getChildSymbols().size()){
			logFile<<"Error at line "<<lineCount<<": Number of arguments doesn't match declaration of function "<<funcSymbol->getName()<<endl<<endl<<code<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Total number of arguments mismatch with declaration in function "<<funcSymbol->getName()<<endl<<endl;
			errorCount++;
		}else{
			bool isMatched=true;
			for(int i=0;i<params.size();i++)
				if(params[i]->getVariant().compare(foundSymbol->getChildSymbols()[i]->getVariant())!=0){
					isMatched=false;
					break;
				}
			if(isMatched) foundSymbol->setGroup(GROUP_FUNCTION_DEFINITION);
			else{
				logFile<<"Error at line "<<lineCount<<": parameter type mismatch of function "<<funcSymbol->getName()<<endl<<endl<<code<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<":  parameter type mismatch of function "<<funcSymbol->getName()<<endl<<endl;
				errorCount++;
			}
		}
	}
	else{
		logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<funcSymbol->getName()<<endl<<endl<<code<<endl<<endl;
		errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<funcSymbol->getName()<<endl<<endl;
		errorCount++;
	}
}


%}

%token ID ELSE LPAREN RPAREN SEMICOLON COMMA LCURL RCURL INT FLOAT VOID LTHIRD CONST_INT RTHIRD FOR IF WHILE PRINTLN RETURN ASSIGNOP RELOP ADDOP MULOP NOT CONST_FLOAT INCOP DECOP  

%left RELOP LOGICOP
%left ADDOP
%left MULOP

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE


%%

start : program
	{
		$$=new SymbolInfo("","start");
		log("program",$$);
		logFile<<symbolTable->printAllScopes();
		logFile<<"Total lines: "<<lineCount<<endl<<"Total errors: "<<errorCount;
	}
	;

program : program unit
	{
		$$=new SymbolInfo($1->getName()+"\n"+$2->getName(),"program");
		log("program unit",$$);
	}
	| unit
	{
		$$=new SymbolInfo($1->getName(),"program");
		log("unit",$$);
	}
	;
	
unit : var_declaration
	 {
		$$=new SymbolInfo($1->getName(),"unit");
		log("var_declaration",$$);
	 }
	 | func_declaration
	 {
		$$=new SymbolInfo($1->getName(),"unit");
		log("func_declaration",$$);
	 }
	 | func_definition
	 {
		$$=new SymbolInfo($1->getName(),"unit");
		log("func_definition",$$);
	 }
     ;

func_definition : type_specifier ID LPAREN parameter_list RPAREN func_body
	{
		$$=new SymbolInfo($1->getName()+" "+$2->getName()+$3->getName()+$4->getName()+$5->getName()+$6->getName(),"func_definition");
		insertFunctionDefinitionToTable($1,$2,$4->getChildSymbols(),$$->getName());
		log("type_specifier ID LPAREN parameter_list RPAREN compound_statement",$$);
	}
	| type_specifier ID LPAREN RPAREN func_body_no_params
	{
		vector<SymbolInfo*> symbols;
		$$=new SymbolInfo($1->getName()+" "+$2->getName()+$3->getName()+$4->getName()+$5->getName(),"func_definition");
		insertFunctionDefinitionToTable($1,$2,symbols,$$->getName());
		log("type_specifier ID LPAREN RPAREN compound_statement",$$);
	}
	;



func_body : LCURL statements RCURL {
		$$=new SymbolInfo($1->getName()+"\n"+$2->getName()+"\n"+$3->getName(),"compound_statement");
		log("LCURL statements RCURL",$$);
	}
	| LCURL RCURL
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"compound_statement");
		log("LCURL RCURL",$$);
	}
	;


	

func_body_no_params : temp_rule statements RCURL {
		$$=new SymbolInfo($1->getName()+"\n"+$2->getName()+"\n"+$3->getName(),"compound_statement");
		log("LCURL statements RCURL",$$);
	}
	| LCURL RCURL
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"compound_statement");
		log("LCURL RCURL",$$);
	}
	;

temp_rule : LCURL {
		symbolTable->enterScope();
	}
	;

var_declaration : type_specifier declaration_list SEMICOLON
     {
		$$=new SymbolInfo($1->getName()+" "+$2->getName()+$3->getName(),"var_declaration");
		insertVariablesToTable($1,$2->getChildSymbols(),$$->getName());
		log("type_specifier declaration_list SEMICOLON",$$);
		if($1->getName().compare(VARIANT_VOID)==0){
			logFile<<"Error at line "<<lineCount<<": Variable type cannot be void"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Variable type cannot be void"<<endl<<endl;
			errorCount++;
		}
		//cout<<$2->getChildSymbols().size()<<endl;
	 }	
 	 ;

declaration_list : declaration_list COMMA ID
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"declaration_list");
		for(int i=0;i<$1->getChildSymbols().size();i++)
			$$->addChildSymbol($1->getChildSymbols()[i]);
		$3->setGroup(GROUP_VARIABLE);
		$$->addChildSymbol($3);
		log("declaration_list COMMA ID",$$);	
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName()+$6->getName(),"declaration_list");
		for(int i=0;i<$1->getChildSymbols().size();i++)
			$$->addChildSymbol($1->getChildSymbols()[i]);
		$3->setGroup(GROUP_ARRAY);
		$$->addChildSymbol($3);
		log("declaration_list COMMA ID LTHIRD CONST_INT RTHIRD",$$);
	}
	| declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName()+$6->getName(),"declaration_list");
		for(int i=0;i<$1->getChildSymbols().size();i++)
			$$->addChildSymbol($1->getChildSymbols()[i]);
		log("declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD",$$);
		logFile<<"Error at line "<<lineCount<<": Expression inside third brackets not an integer"<<endl<<endl<<$$->getName()<<endl<<endl;
		errorFile<<"Error at line "<<lineCount<<": Expression inside third brackets not an integer"<<endl<<endl;
		errorCount++;
	}
	| ID
	{
		$$=new SymbolInfo($1->getName(),"declaration_list");
		$1->setGroup(GROUP_VARIABLE);
		$$->addChildSymbol($1);
		log("ID",$$);
	}
	| ID LTHIRD CONST_INT RTHIRD
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName(),"declaration_list");
		$1->setGroup(GROUP_ARRAY);
		$$->addChildSymbol($1);
		log("ID LTHIRD CONST_INT RTHIRD",$$);
	}
	|
	ID LTHIRD CONST_FLOAT RTHIRD
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName(),"declaration_list");
		log("ID LTHIRD CONST_INT RTHIRD",$$);
		logFile<<"Error at line "<<lineCount<<": Expression inside third brackets not an integer"<<endl<<endl<<$$->getName()<<endl<<endl;
		errorFile<<"Error at line "<<lineCount<<": Expression inside third brackets not an integer"<<endl<<endl;
		errorCount++;
	}
	;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
		{
			symbolTable->exitScope();
			$$=new SymbolInfo($1->getName()+" "+$2->getName()+$3->getName()+$4->getName()+$5->getName()+$6->getName(),"func_declaration");
			insertFunctionDeclarationToTable($1,$2,$4->getChildSymbols(),$$->getName());
			log("type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",$$);
		}
		| type_specifier ID LPAREN RPAREN SEMICOLON
		{
			symbolTable->enterScope();
			symbolTable->exitScope();
			vector<SymbolInfo*> symbols;
			$$=new SymbolInfo($1->getName()+" "+$2->getName()+$3->getName()+$4->getName()+$5->getName(),"func_declaration");
			insertFunctionDeclarationToTable($1,$2,symbols,$$->getName());
			log("type_specifier ID LPAREN RPAREN SEMICOLON",$$);
		}
		;

parameter_list  : parameter_list COMMA type_specifier ID
		{
			$$=$1;
			$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+" "+$4->getName(),"parameter_list");
			for(int i=0;i<$1->getChildSymbols().size();i++)
				$$->addChildSymbol($1->getChildSymbols()[i]);
			$4->setVariant($3->getName());
			$4->setGroup(GROUP_VARIABLE);
			bool isInserted=symbolTable->insertSymbol($4);
			log("parameter_list COMMA type_specifier ID",$$);
			if(!isInserted){
				logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<$4->getName()<<" in parameter"<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<$4->getName()<<" in parameter"<<endl<<endl;
				errorCount++;
			}
			$$->addChildSymbol($4);
		}
		| parameter_list COMMA type_specifier
		{
			$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"parameter_list");
			for(int i=0;i<$1->getChildSymbols().size();i++)
				$$->addChildSymbol($1->getChildSymbols()[i]);
			SymbolInfo *newSymbol=new SymbolInfo(NULL,"ID");
			newSymbol->setVariant($3->getName());
			newSymbol->setGroup(GROUP_VARIABLE);
			bool isInserted=symbolTable->insertSymbol(newSymbol);
			log("parameter_list COMMA type_specifier",$$);
			if(!isInserted){
				logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<newSymbol->getName()<<" in parameter"<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<newSymbol->getName()<<" in parameter"<<endl<<endl;
				errorCount++;
			}
			$$->addChildSymbol(newSymbol);
		}
 		| type_specifier ID
		 {
			symbolTable->enterScope();
			$$=new SymbolInfo($1->getName()+" "+$2->getName(),"parameter_list");
			$2->setVariant($1->getName());
			$2->setGroup(GROUP_VARIABLE);
			bool isInserted=symbolTable->insertSymbol($2);
			log("type_specifier ID",$$);
			if(!isInserted){
				logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<$2->getName()<<" in parameter"<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<$2->getName()<<" in parameter"<<endl<<endl;
				errorCount++;
			}
			$$->addChildSymbol($2);
		 }
		| type_specifier
		{
			symbolTable->enterScope();
			$$=new SymbolInfo($1->getName(),"parameter_list");
			SymbolInfo *newSymbol=new SymbolInfo(NULL,"ID");
			newSymbol->setVariant($1->getName());
			newSymbol->setGroup(GROUP_VARIABLE);
			bool isInserted=symbolTable->insertSymbol(newSymbol);
			log("type_specifier",$$);
			if(!isInserted){
				logFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<newSymbol->getName()<<" in parameter"<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Multiple declaration of "<<newSymbol->getName()<<" in parameter"<<endl<<endl;
				errorCount++;
			}
			$$->addChildSymbol(newSymbol);
		}
 		;

 		 
type_specifier	: INT
		{
			$$=new SymbolInfo($1->getName(),"type_specifier");
			log("INT",$$);
		}
 		| FLOAT
		{
			$$=new SymbolInfo($1->getName(),"type_specifier");
			log("FLOAT",$$);
		}
 		| VOID 
		{
			$$=new SymbolInfo($1->getName(),"type_specifier");
			log("VOID",$$);
		}
 		;


compound_statement : LCURL {
		symbolTable->enterScope();
	} statements RCURL {
		$$=new SymbolInfo($1->getName()+"\n"+$3->getName()+"\n"+$4->getName(),"compound_statement");
		log("LCURL statements RCURL",$$);
		logFile<<symbolTable->printAllScopes();
		symbolTable->exitScope();
	}
	| LCURL RCURL
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"compound_statement");
		log("LCURL RCURL",$$);
	}
	;

statements : statement
	{
		$$=new SymbolInfo($1->getName(),"statements");
		log("statement",$$);
	}
	| statements statement
	{
		$$=new SymbolInfo($1->getName()+"\n"+$2->getName(),"statements");
		log("statements statement",$$);
	}
	;
	   
statement : var_declaration
	{
		$$=new SymbolInfo($1->getName(),"statement");
		log("var_declaration",$$);
	}
	| expression_statement
	{
		$$=new SymbolInfo($1->getName(),"statement");
		log("expression_statement",$$);
	}
	| compound_statement
	{
		$$=new SymbolInfo($1->getName(),"statement");
		log("compound_statement",$$);
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName()+$6->getName()+$7->getName(),"statement");
		log("FOR LPAREN expression_statement expression_statement expression RPAREN statement",$$);
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName(),"statement");
		log("IF LPAREN expression RPAREN statement",$$);
	}
	| IF LPAREN expression RPAREN statement ELSE statement
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName()+"\n"+$6->getName()+"\n"+$7->getName(),"statement");
		log("IF LPAREN expression RPAREN statement ELSE statement",$$);
	}
	| WHILE LPAREN expression RPAREN statement
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName(),"statement");
		log("WHILE LPAREN expression RPAREN statement",$$);
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName()+$5->getName(),"statement");
		log("PRINTLN LPAREN ID RPAREN SEMICOLON",$$);
		SymbolInfo *foundSymbol=symbolTable->lookup($3->getName());
		if(foundSymbol==NULL || foundSymbol->getGroup().compare(GROUP_FUNCTION_DECLARATION)==0 || foundSymbol->getGroup().compare(GROUP_FUNCTION_DEFINITION)==0){
			logFile<<"Error at line "<<lineCount<<": Undeclared variable "<<$3->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Undeclared variable "<<$3->getName()<<endl<<endl;
			errorCount++;
		}
	}
	| RETURN expression SEMICOLON
	{
		$$=new SymbolInfo($1->getName()+" "+$2->getName()+$3->getName(),"statement");
		log("RETURN expression SEMICOLON",$$);
	}
	;

expression_statement : SEMICOLON
	{
		$$=new SymbolInfo($1->getName(),"expression_statement");
		log("SEMICOLON",$$);
	}			
	| expression SEMICOLON 
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"expression_statement");
		log("expression SEMICOLON",$$);
	}
	;

variable : ID 
	{
		$$=new SymbolInfo($1->getName(),"variable");
		log("ID",$$);
		SymbolInfo *foundSymbol=symbolTable->lookup($1->getName());
		if(foundSymbol==NULL || foundSymbol->getGroup().compare(GROUP_FUNCTION_DECLARATION)==0 || foundSymbol->getGroup().compare(GROUP_FUNCTION_DEFINITION)==0){
			logFile<<"Error at line "<<lineCount<<": Undeclared variable "<<$1->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Undeclared variable "<<$1->getName()<<endl<<endl;
			errorCount++;
			$$->setGroup(GROUP_VARIABLE);
			$$->setVariant(VARIANT_UNDEFINED);
		}else{
			$$->setGroup(foundSymbol->getGroup());
			$$->setVariant(foundSymbol->getVariant());
		}
	}		
	| ID LTHIRD expression RTHIRD
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName(),"variable");
		log("ID LTHIRD expression RTHIRD",$$);
		SymbolInfo *foundSymbol=symbolTable->lookup($1->getName());
		if(foundSymbol->getGroup().compare(GROUP_VARIABLE)==0){
			logFile<<"Error at line "<<lineCount<<": "<<$1->getName()<<" is not an array"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": "<<$1->getName()<<" is not an array"<<endl<<endl;
			errorCount++;
			$$->setGroup(GROUP_VARIABLE);
			$$->setVariant(VARIANT_UNDEFINED);
		}
		else if(foundSymbol==NULL || foundSymbol->getGroup().compare(GROUP_FUNCTION_DECLARATION)==0 || foundSymbol->getGroup().compare(GROUP_FUNCTION_DEFINITION)==0){
			logFile<<"Error at line "<<lineCount<<": Undeclared variable "<<$1->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Undeclared variable "<<$1->getName()<<endl<<endl;
			errorCount++;
			$$->setGroup(GROUP_VARIABLE);
			$$->setVariant(VARIANT_UNDEFINED);
		}else{
			$$->setGroup(GROUP_VARIABLE);
			$$->setVariant(foundSymbol->getVariant());
		}
		if($3->getVariant().compare(VARIANT_INT)!=0){
			logFile<<"Error at line "<<lineCount<<": Expression inside third brackets not an integer"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Expression inside third brackets not an integer"<<endl<<endl;
			errorCount++;
		}
	} 
	;

expression : logic_expression
	{
		$$=new SymbolInfo($1->getName(),"expression");
		$$->setVariant($1->getVariant());
		log("logic_expression",$$);
		$$->setGroup($1->getGroup());
	}	
	| variable ASSIGNOP logic_expression 
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"expression");
		log("variable ASSIGNOP logic_expression",$$);
		if($1->getVariant().compare(VARIANT_UNDEFINED)==0 || $3->getVariant().compare(VARIANT_UNDEFINED)==0);
		else if($1->getGroup().compare(GROUP_ARRAY)==0){
			logFile<<"Error at line "<<lineCount<<": Type mismatch, "<<$1->getName()<<" is an array"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Type mismatch, "<<$1->getName()<<" is an array"<<endl<<endl;
			errorCount++;
		}
		else if(!($1->getVariant().compare(VARIANT_FLOAT)==0 && $3->getVariant().compare(VARIANT_INT)==0) && $1->getVariant().compare($3->getVariant())!=0){
			logFile<<"Error at line "<<lineCount<<": Type Mismatch"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Type Mismatch"<<endl<<endl;
			errorCount++;
		}
		$$->setVariant(VARIANT_INT);
		$$->setGroup($1->getGroup());
	}	
	;
			
logic_expression : rel_expression
	{
		$$=new SymbolInfo($1->getName(),"logic_expression");
		$$->setVariant($1->getVariant());
		log("rel_expression",$$);
		$$->setGroup($1->getGroup());
	}	
	| rel_expression LOGICOP rel_expression 
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"logic_expression");
		$$->setVariant(VARIANT_INT);
		log("rel_expression LOGICOP rel_expression",$$);
		$$->setGroup($1->getGroup());
	}	
	;
			
rel_expression	: simple_expression
	{
		$$=new SymbolInfo($1->getName(),"rel_expression");
		$$->setVariant($1->getVariant());
		log("simple_expression",$$);
		$$->setGroup($1->getGroup());
	} 
	| simple_expression RELOP simple_expression
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"rel_expression");
		$$->setVariant(VARIANT_INT);
		log("simple_expression RELOP simple_expression",$$);
		$$->setGroup($1->getGroup());
	}
	;
				
simple_expression : term
	{
		$$=new SymbolInfo($1->getName(),"simple_expression");
		$$->setVariant($1->getVariant());
		log("term",$$);
		$$->setGroup($1->getGroup());
	}
	| simple_expression ADDOP term
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"simple_expression");
		if($1->getVariant().compare(VARIANT_FLOAT)==0 || $3->getVariant().compare(VARIANT_FLOAT)==0)
			$$->setVariant(VARIANT_FLOAT);
		else if($1->getVariant().compare(VARIANT_INT)==0 || $3->getVariant().compare(VARIANT_INT)==0)
			$$->setVariant(VARIANT_INT);
		else $$->setVariant(VARIANT_UNDEFINED);
		log("simple_expression ADDOP term",$$);
		$$->setGroup($1->getGroup());
	}
	;
					
term :	unary_expression
	{
		$$=new SymbolInfo($1->getName(),"term");
		$$->setVariant($1->getVariant());
		$$->setGroup($1->getGroup());
		log("unary_expression",$$);
	}
     |  term MULOP unary_expression
	 {
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"term");
		if($1->getVariant().compare(VARIANT_FLOAT)==0 || $3->getVariant().compare(VARIANT_FLOAT)==0)
			$$->setVariant(VARIANT_FLOAT);
		else if($1->getVariant().compare(VARIANT_INT)==0 || $3->getVariant().compare(VARIANT_INT)==0)
			$$->setVariant(VARIANT_INT);
		else $$->setVariant(VARIANT_UNDEFINED);
		log("term MULOP unary_expression",$$);
		if($2->getName().compare("%")==0 && !($1->getVariant().compare(VARIANT_INT)==0 && $3->getVariant().compare(VARIANT_INT)==0)){
			logFile<<"Error at line "<<lineCount<<": Non-Integer operand on modulus operator"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Non-Integer operand on modulus operator"<<endl<<endl;
			errorCount++;
		}
		if($2->getName().compare("%")==0 && $3->getName().compare("0")==0){
			logFile<<"Error at line "<<lineCount<<": Modulus by Zero"<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Modulus by Zero"<<endl<<endl;
			errorCount++;
		}
		if($2->getName().compare("%")==0)$$->setVariant(VARIANT_INT);
		$$->setGroup($1->getGroup());
	 }
     ;

unary_expression : ADDOP unary_expression
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"unary_expression");
		$$->setVariant($2->getVariant());
		$$->setGroup($2->getGroup());
		log("ADDOP unary_expression",$$);
	}
	| NOT unary_expression 
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"unary_expression");
		$$->setVariant($2->getVariant());
		$$->setGroup($2->getGroup());
		log("NOT unary_expression",$$);
	}
	| factor
	{
		$$=new SymbolInfo($1->getName(),"unary_expression");
		$$->setVariant($1->getVariant());
		$$->setGroup($1->getGroup());
		log("factor",$$);
	} 
	;
	
factor	: variable
	{
		$$=new SymbolInfo($1->getName(),"factor");
		log("variable",$$);
		$$->setVariant($1->getVariant());
		$$->setGroup($1->getGroup());
	}
	| ID LPAREN argument_list RPAREN
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName()+$4->getName(),"factor");
		SymbolInfo *foundSymbol=symbolTable->lookup($1->getName());
		log("ID LPAREN argument_list RPAREN",$$);
		if(foundSymbol==NULL){
			logFile<<"Error at line "<<lineCount<<": Undeclared function : "<<$1->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Undeclared function : "<<$1->getName()<<endl<<endl;
			errorCount++;
			$$->setVariant(VARIANT_UNDEFINED);
		}else if(foundSymbol->getGroup().compare(GROUP_ARRAY)==0 || foundSymbol->getGroup().compare(GROUP_VARIABLE)==0){
			logFile<<"Error at line "<<lineCount<<": Function call made with non function type identifier : "<<$1->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
			errorFile<<"Error at line "<<lineCount<<": Function call made with non function type identifier : "<<$1->getName()<<endl<<endl;
			errorCount++;
		}else{
			$$->setVariant(foundSymbol->getVariant());
			if(foundSymbol->getGroup().compare(GROUP_FUNCTION_DECLARATION)==0){
				logFile<<"Error at line "<<lineCount<<": Undefined function : "<<$1->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Undefined function : "<<$1->getName()<<endl<<endl;
				errorCount++;
			}
			if(foundSymbol->getVariant().compare(VARIANT_VOID)==0){
				$$->setVariant(VARIANT_UNDEFINED);
				logFile<<"Error at line "<<lineCount<<": Void function used in expression"<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Void function used in expression"<<endl<<endl;
				errorCount++;
			}

			if($3->getChildSymbols().size()!=foundSymbol->getChildSymbols().size()){
				logFile<<"Error at line "<<lineCount<<": Total number of arguments mismatch in function "<<foundSymbol->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
				errorFile<<"Error at line "<<lineCount<<": Total number of arguments mismatch in function "<<foundSymbol->getName()<<endl<<endl;
				errorCount++;
			}else{
				for(int i=0;i<$3->getChildSymbols().size();i++){
					if($3->getChildSymbols()[i]->getGroup().compare(GROUP_ARRAY)==0){
						logFile<<"Error at line "<<lineCount<<": Type mismatch: "<<$3->getChildSymbols()[i]->getName()<<" is an array"<<endl<<endl<<$$->getName()<<endl<<endl;
						errorFile<<"Error at line "<<lineCount<<": Type mismatch: "<<$3->getChildSymbols()[i]->getName()<<" is an array"<<endl<<endl;
						errorCount++;
						break;
					}
					else if($3->getChildSymbols()[i]->getVariant().compare(VARIANT_FLOAT)==0 && foundSymbol->getChildSymbols()[i]->getVariant().compare(VARIANT_INT)==0){
						logFile<<"Error at line "<<lineCount<<": "<<i+1<<"th argument mismatch in function "<<foundSymbol->getName()<<endl<<endl<<$$->getName()<<endl<<endl;
						errorFile<<"Error at line "<<lineCount<<": "<<i+1<<"th argument mismatch in function "<<foundSymbol->getName()<<endl<<endl;
						errorCount++;
						break;
					}
				}
			}
			$$->setGroup(GROUP_VARIABLE);
		}
	}
	| LPAREN expression RPAREN
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"factor");
		$$->setVariant($2->getVariant());
		$$->setGroup($2->getGroup());
		log("LPAREN expression RPAREN",$$);
	}
	| CONST_INT
	{
		$$=new SymbolInfo($1->getName(),"factor");
		$$->setVariant(VARIANT_INT);
		$$->setGroup(GROUP_VARIABLE);
		log("CONST_INT",$$);
	} 
	| CONST_FLOAT
	{
		$$=new SymbolInfo($1->getName(),"factor");
		$$->setVariant(VARIANT_FLOAT);
		$$->setGroup(GROUP_VARIABLE);
		log("CONST_FLOAT",$$);
	}
	| variable INCOP{
		$$=new SymbolInfo($1->getName()+$2->getName(),"factor");
		$$->setVariant($1->getVariant());
		$$->setGroup($1->getGroup());
		log("variable INCOP",$$);
	} 
	| variable DECOP
	{
		$$=new SymbolInfo($1->getName()+$2->getName(),"factor");
		$$->setVariant($1->getVariant());
		$$->setGroup($1->getGroup());
		log("variable DECOP",$$);
	}
	;
	
argument_list : arguments
	{
		$$=new SymbolInfo($1->getName(),"argument_list");
		log("arguments",$$);
		for(int i=0;i<$1->getChildSymbols().size();i++)
			$$->addChildSymbol($1->getChildSymbols()[i]);
	}
	;
	
arguments : arguments COMMA logic_expression
	{
		$$=new SymbolInfo($1->getName()+$2->getName()+$3->getName(),"arguments");
		for(int i=0;i<$1->getChildSymbols().size();i++)
			$$->addChildSymbol($1->getChildSymbols()[i]);
		SymbolInfo *newSymbol=new SymbolInfo($3->getName(),$3->getType());
		newSymbol->setVariant($3->getVariant());
		newSymbol->setGroup($3->getGroup());
		$$->addChildSymbol(newSymbol);
		log("arguments COMMA logic_expression",$$);
	}
	| logic_expression
	{
		$$=new SymbolInfo($1->getName(),"arguments");
		$$->setVariant($1->getVariant());
		$$->addChildSymbol($$);
		$$->setGroup($1->getGroup());
		log("logic_expression",$$);
	}
	;

 

%%
int main(int argc,char *argv[])
{

	FILE *fp;

	if((fp=fopen(argv[1],"r"))==NULL)
	{
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	symbolTable=new SymbolTable(7);

	logFile.open("1805001_log.txt");
	errorFile.open("1805001_error.txt");

	yyin=fp;
	yyparse();
	

	fclose(fp);
	logFile.close();
	
	return 0;
}

