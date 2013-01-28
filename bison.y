/*
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */


%{

#include "lex.yy.c"
#include "cm.cu"


    void clean_queues();
    void order_inplace(CudaSet* a, stack<string> exe_type);
    void yyerror(char *s, ...);
    void emit(char *s, ...);
    void emit_mul();
    void emit_add();
    void emit_minus();
	void emit_distinct();
    void emit_div();
    void emit_and();
    void emit_eq();
    void emit_or();
    void emit_cmp(int val);
    void emit_var(char *s, int c, char *f);
    void emit_var_asc(char *s);
    void emit_var_desc(char *s);
    void emit_name(char *name);
    void emit_count();
    void emit_sum();
    void emit_average();
    void emit_min();
    void emit_max();
    void emit_string(char *str);
    void emit_number(int_type val);
    void emit_float(float_type val);
    void emit_decimal(float_type val);
    void emit_sel_name(char* name);
    void emit_limit(int val);
    void emit_union(char *s, char *f1, char *f2);
    void emit_varchar(char *s, int c, char *f, int d);
    void emit_load(char *s, char *f, int d, char* sep);
    void emit_load_binary(char *s, char *f, int d);
    void emit_store(char *s, char *f, char* sep);
    void emit_store_binary(char *s, char *f, char* sep);
    void emit_store_binary(char *s, char *f);
    void emit_filter(char *s, char *f, int e);
    void emit_order(char *s, char *f, int e, int ll = 0);
    void emit_group(char *s, char *f, int e);
    void emit_select(char *s, char *f, int ll);
    void emit_join(char *s, char *j1);
    void emit_join_tab(char *s);
    void emit_distinct();

%}

%union {
    int intval;
    float floatval;
    char *strval;
    int subtok;
}

%token <strval> FILENAME
%token <strval> NAME
%token <strval> STRING
%token <intval> INTNUM
%token <intval> DECIMAL1
%token <intval> BOOL1
%token <floatval> APPROXNUM
/* user @abc names */
%token <strval> USERVAR
/* operators and precedence levels */
%right ASSIGN
%right EQUAL
%left OR
%left XOR
%left AND
%left DISTINCT
%nonassoc IN IS LIKE REGEXP
%left NOT '!'
%left BETWEEN
%left <subtok> COMPARISON /* = <> < > <= >= <=> */
%left '|'
%left '&'
%left <subtok> SHIFT /* << >> */
%left '+' '-'
%left '*' '/' '%' MOD
%left '^'
%nonassoc UMINUS

%token AND
%token OR
%token LOAD
%token STREAM
%token FILTER
%token BY
%token JOIN
%token STORE
%token INTO
%token GROUP
%token FROM
%token SELECT
%token AS
%token ORDER
%token ASC
%token DESC
%token COUNT
%token USING
%token SUM
%token AVG
%token MIN
%token MAX
%token LIMIT
%token ON
%token BINARY
%token DISTINCT


%type <intval> load_list  opt_where opt_limit
%type <intval> val_list opt_val_list expr_list opt_group_list join_list
%start stmt_list
%%


/* Grammar rules and actions follow. */

stmt_list:
stmt ';'
| stmt_list stmt ';'
;

stmt:
select_stmt { emit("STMT"); }
;
select_stmt:
NAME ASSIGN SELECT expr_list FROM NAME opt_group_list
{ emit_select($1, $6, $7); } ;
| NAME ASSIGN LOAD FILENAME USING '(' FILENAME ')' AS '(' load_list ')'
{  emit_load($1, $4, $11, $7); } ;
| NAME ASSIGN LOAD FILENAME BINARY AS '(' load_list ')'
{  emit_load_binary($1, $4, $8); } ;
| NAME ASSIGN FILTER NAME opt_where
{  emit_filter($1, $4, $5);}
| NAME ASSIGN ORDER NAME BY opt_val_list
{  emit_order($1, $4, $6);}
| NAME ASSIGN SELECT expr_list FROM NAME join_list
{ emit_join($1,$6); }
| STORE NAME INTO FILENAME USING '(' FILENAME ')' opt_limit
{ emit_store($2,$4,$7); }
| STORE NAME INTO FILENAME opt_limit BINARY
{ emit_store_binary($2,$4); }
;

expr:
NAME { emit_name($1); }
| NAME '.' NAME { emit("FIELDNAME %s.%s", $1, $3); }
| USERVAR { emit("USERVAR %s", $1); }
| STRING { emit_string($1); }
| INTNUM { emit_number($1); }
| APPROXNUM { emit_float($1); }
| DECIMAL1 { emit_decimal($1); }
| BOOL1 { emit("BOOL %d", $1); }
| NAME '{' INTNUM '}' ':' NAME '(' INTNUM ')' { emit_varchar($1, $3, $6, $8);}
| NAME '{' INTNUM '}' ':' NAME  { emit_var($1, $3, $6);}
| NAME ASC { emit_var_asc($1);}
| NAME DESC { emit_var_desc($1);}
| COUNT '(' expr ')' { emit_count(); }
| SUM '(' expr ')' { emit_sum(); }
| AVG '(' expr ')' { emit_average(); }
| MIN '(' expr ')' { emit_min(); }
| MAX '(' expr ')' { emit_max(); }
| DISTINCT expr { emit_distinct(); }
;

expr:
expr '+' expr { emit_add(); }
| expr '-' expr { emit_minus(); }
| expr '*' expr { emit_mul(); }
| expr '/' expr { emit_div(); }
| expr '%' expr { emit("MOD"); }
| expr MOD expr { emit("MOD"); }
/*| '-' expr %prec UMINUS { emit("NEG"); }*/
| expr AND expr { emit_and(); }
| expr EQUAL expr { emit_eq(); }
| expr OR expr { emit_or(); }
| expr XOR expr { emit("XOR"); }
| expr SHIFT expr { emit("SHIFT %s", $2==1?"left":"right"); }
| NOT expr { emit("NOT"); }
| '!' expr { emit("NOT"); }
| expr COMPARISON expr { emit_cmp($2); }
/* recursive selects and comparisons thereto */
| expr COMPARISON '(' select_stmt ')' { emit("CMPSELECT %d", $2); }
| '(' expr ')' {emit("EXPR");}
;

expr:
expr IS BOOL1 { emit("ISBOOL %d", $3); }
| expr IS NOT BOOL1 { emit("ISBOOL %d", $4); emit("NOT"); }
;

opt_group_list: { /* nil */
    $$ = 0;
}
| GROUP BY val_list { $$ = $3}


expr_list:
expr AS NAME { $$ = 1; emit_sel_name($3);}
| expr_list ',' expr AS NAME { $$ = $1 + 1; emit_sel_name($5);}
;

load_list:
expr { $$ = 1; }
| load_list ',' expr {$$ = $1 + 1; }
;

val_list:
expr { $$ = 1; }
| expr ',' val_list { $$ = 1 + $3; }
;

opt_val_list: { /* nil */
    $$ = 0
}  | val_list;

opt_where:
BY expr { emit("FILTER BY"); };

join_list:
JOIN NAME ON expr { $$ = 1; emit_join_tab($2);}
| JOIN NAME ON expr join_list { $$ = 1; emit_join_tab($2); };

opt_limit: { /* nil */
    $$ = 0
}
     | LIMIT INTNUM { emit_limit($2); };


%%

#include "filter.cu"
#include "select.cu"
#include "merge.cu"
#include "zone_map.cu"

FILE *file_pointer;
queue<string> namevars;
queue<string> typevars;
queue<int> sizevars;
queue<int> cols;

queue<unsigned int> j_col_count;
unsigned int sel_count = 0;
unsigned int join_cnt = 0;
int join_col_cnt = 0;
unsigned int eqq = 0;
stack<string> op_join;

unsigned int statement_count = 0;
map<string,unsigned int> stat;
bool scan_state = 0;
string separator, f_file;
			


//CUDPPHandle theCudpp;

using namespace thrust::placeholders;


void emit_name(char *name)
{
    op_type.push("NAME");
    op_value.push(name);
}

void emit_limit(int val)
{
    op_nums.push(val);
}


void emit_string(char *str)
{   // remove the float_type quotes
    string sss(str,1, strlen(str)-2);
    op_type.push("STRING");
    op_value.push(sss);
}


void emit_number(int_type val)
{
    op_type.push("NUMBER");
    op_nums.push(val);
}

void emit_float(float_type val)
{
    op_type.push("FLOAT");
    op_nums_f.push(val);
}

void emit_decimal(float_type val)
{
    op_type.push("DECIMAL");
    op_nums_f.push(val);
}



void emit_mul()
{
    op_type.push("MUL");
}

void emit_add()
{
    op_type.push("ADD");
}

void emit_div()
{
    op_type.push("DIV");
}

void emit_and()
{
    op_type.push("AND");
    if (join_col_cnt == -1)
        join_col_cnt++;
    join_col_cnt++;
    eqq = 0;
}

void emit_eq()
{
    //op_type.push("JOIN");
    eqq++;
    join_cnt++;
    if(eqq == join_col_cnt+1) {
        j_col_count.push(join_col_cnt+1);
        join_col_cnt = -1;
    }
    else if (join_col_cnt == -1 )
        j_col_count.push(1);

}

void emit_distinct()
{
    op_type.push("DISTINCT");
}

void emit_or()
{
    op_type.push("OR");
}


void emit_minus()
{
    op_type.push("MINUS");
}

void emit_cmp(int val)
{
    op_type.push("CMP");
    op_nums.push(val);
}

void emit(char *s, ...)
{


}

void emit_var(char *s, int c, char *f)
{
    namevars.push(s);
    typevars.push(f);
    sizevars.push(0);
    cols.push(c);
}

void emit_var_asc(char *s)
{
    op_type.push(s);
    op_value.push("ASC");
}

void emit_var_desc(char *s)
{
    op_type.push(s);
    op_value.push("DESC");
}


void emit_varchar(char *s, int c, char *f, int d)
{
    namevars.push(s);
    typevars.push(f);
    sizevars.push(d);
    cols.push(c);
}

void emit_sel_name(char *s)
{
    op_type.push("emit sel_name");
    op_value.push(s);
    sel_count++;
}

void emit_count()
{
    op_type.push("COUNT");
}

void emit_sum()
{
    op_type.push("SUM");
}


void emit_average()
{
    op_type.push("AVG");
}

void emit_min()
{
    op_type.push("MIN");
}

void emit_max()
{
    op_type.push("MAX");
}

void emit_join_tab(char *s)
{
    op_join.push(s);
};




void order_inplace(CudaSet* a, stack<string> exe_type, set<string> field_names, unsigned int segment)
{
    //std::clock_t start1 = std::clock();
    unsigned int sz = a->mRecCount;
    thrust::device_ptr<unsigned int> permutation = thrust::device_malloc<unsigned int>(sz);
    thrust::sequence(permutation, permutation+sz,0,1);


    unsigned int* raw_ptr = thrust::raw_pointer_cast(permutation);
    void* temp;
    // find the largest mRecSize of all data sources exe_type.top()
    unsigned int maxSize = 0;
    for (set<string>::iterator it=field_names.begin(); it!=field_names.end(); ++it) {
        CudaSet *t = varNames[setMap[*it]];
        if(t->mRecCount > maxSize)
            maxSize = t->mRecCount;
    };

    //cout << "max size " << maxSize << endl;
    //cout << "sort alloc " << maxSize << endl;
    //cout << "order mem " << getFreeMem() << endl;
	unsigned int max_char = 0;
	for(unsigned int i = 0; i < a->char_size.size(); i++)
	    if (a->char_size[a->type_index[i]] > max_char)
		    max_char = a->char_size[a->type_index[i]];
			
	
    if(max_char > float_size)	
	    CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*max_char));
	else	
        CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*float_size));
	

    for(int i=0; !exe_type.empty(); ++i, exe_type.pop()) {
        int colInd = (a->columnNames).find(exe_type.top())->second;
        if ((a->type)[colInd] == 0)
            update_permutation(a->d_columns_int[a->type_index[colInd]], raw_ptr, sz, "ASC", (int_type*)temp);
        else if ((a->type)[colInd] == 1)
            update_permutation(a->d_columns_float[a->type_index[colInd]], raw_ptr, sz,"ASC", (float_type*)temp);
        else {
			update_permutation_char(a->d_columns_char[a->type_index[colInd]], raw_ptr, sz, "ASC", (char*)temp, a->char_size[a->type_index[colInd]]);	
				
        };
    };
	

    for (set<string>::iterator it=field_names.begin(); it!=field_names.end(); ++it) {
        int i = a->columnNames[*it];
        if ((a->type)[i] == 0)
            apply_permutation(a->d_columns_int[a->type_index[i]], raw_ptr, sz, (int_type*)temp);
        else if ((a->type)[i] == 1)
            apply_permutation(a->d_columns_float[a->type_index[i]], raw_ptr, sz, (float_type*)temp);
        else {
			apply_permutation_char(a->d_columns_char[a->type_index[i]], raw_ptr, sz, (char*)temp, a->char_size[a->type_index[i]]);
        };
    };

    cudaFree(temp);
    thrust::device_free(permutation);
	
}





void emit_join(char *s, char *j1)
{

    string j2 = op_join.top();
    op_join.pop();

    statement_count++;
    if (scan_state == 0) {
        if (stat.find(j1) == stat.end()) {
            cout << "Join : couldn't find variable " << j1 << endl;
            exit(1);
        };
        if (stat.find(j2) == stat.end()) {
            cout << "Join : couldn't find variable " << j2 << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[j1] = statement_count;
        stat[j2] = statement_count;
        return;
    };
 

    if(varNames.find(j1) == varNames.end() || varNames.find(j2) == varNames.end()) {
        clean_queues();
        return;
    };

    CudaSet* left = varNames.find(j1)->second;
    CudaSet* right = varNames.find(j2)->second;
	
    queue<string> op_sel;
    queue<string> op_sel_as;
    for(int i=0; i < sel_count; i++) {
        op_sel.push(op_value.front());
        op_value.pop();
        op_sel_as.push(op_value.front());
        op_value.pop();
    };

    string f1 = op_value.front();
    op_value.pop();
    string f2 = op_value.front();
    op_value.pop();

    cout << "JOIN " << s <<  " " <<  getFreeMem() <<  endl;	


    std::clock_t start1 = std::clock();
    CudaSet* c = new CudaSet(right,left,0,op_sel, op_sel_as);	

    if (left->mRecCount == 0 || right->mRecCount == 0) {
        c = new CudaSet(left,right,0, op_sel, op_sel_as);        
        varNames[s] = c;
        clean_queues();
        return;
    };

    unsigned int colInd1 = (left->columnNames).find(f1)->second;
    unsigned int colInd2 = (right->columnNames).find(f2)->second;
	
	if (!((left->type[colInd1] == 0 && right->type[colInd2]  == 0) || (left->type[colInd1] == 2 && right->type[colInd2]  == 2))) {
	    cout << "Only joins on integers and strings are supported " << endl;
		exit(0);
	};	

    set<string> field_names;
    stack<string> exe_type;
    exe_type.push(f2);
    field_names.insert(f2);
	
	bool str_join = 0;
	//if join is on strings then add integer columns to left and right tables and modify colInd1 and colInd2
	
	if (right->type[colInd2]  == 2) {
	    str_join = 1;
		right->d_columns_int.push_back(thrust::device_vector<int_type>());		
		for(unsigned int i = 0; i < right->segCount; i++) {
		    right->add_hashed_strings(colInd2, i);
		};			
	};	
	

    // need to allocate all right columns	
    queue<string> cc;
	unsigned int rcount;
	
	unsigned int cnt_r = load_queue(op_sel, right, str_join, f2, rcount);	

    if(str_join) {	
        colInd2 = right->mColumnCount+1;
	    right->type_index[colInd2] = right->d_columns_int.size()-1;		
	};	

	
	
	unsigned int tt;
    if(left->maxRecs > rcount)	
	    tt = left->maxRecs;
	else
        tt = rcount;
		
	
	//here we need to make sure that right column is ordered. If not then we order it and keep the permutation	
	
	
		
	bool sorted = thrust::is_sorted(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r);
	
  	
	if(!sorted) {
	
	    thrust::device_vector<unsigned int> v(cnt_r);
	    thrust::sequence(v.begin(),v.end(),0,1);
	    thrust::device_ptr<int_type> d_tmp = thrust::device_malloc<int_type>(tt);			
	
	    thrust::sort_by_key(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r, v.begin());
		for(unsigned int i = 0; i < right->mColumnCount; i++) {
		    if(i != colInd2) {
			    if(right->type[i] == 0) {
			        thrust::gather(v.begin(), v.end(), right->d_columns_int[right->type_index[i]].begin(), d_tmp);
				    thrust::copy(d_tmp, d_tmp + cnt_r, right->d_columns_int[right->type_index[i]].begin());					
				}
			    else if(right->type[i] == 1) {			
			        thrust::gather(v.begin(), v.end(), right->d_columns_float[right->type_index[i]].begin(), d_tmp);
				    thrust::copy(d_tmp, d_tmp + cnt_r, right->d_columns_float[right->type_index[i]].begin());
				}        
                else {
                    str_gather(thrust::raw_pointer_cast(v.data()), cnt_r, (void*)left->d_columns_char[left->type_index[i]], (void*) thrust::raw_pointer_cast(d_tmp), left->char_size[left->type_index[i]]);
					cudaMemcpy( (void*)left->d_columns_char[left->type_index[i]], (void*) thrust::raw_pointer_cast(d_tmp), cnt_r*left->char_size[left->type_index[i]], cudaMemcpyDeviceToDevice);		            
					
                };				
			};	
		};
		thrust::device_free(d_tmp);	
	};
	
	
		
	while(!cc.empty())
        cc.pop();

	if (left->type[colInd1]  == 2) {
		left->d_columns_int.push_back(thrust::device_vector<int_type>());		
		//colInd1 = left->mColumnCount+1;
		//left->type_index[colInd1] = left->d_columns_int.size()-1;		
	}
    else {		
        cc.push(f1);
        allocColumns(left, cc);	
	};	

    //cout << "successfully loaded l && r " << cnt_l << " " << cnt_r << " " << getFreeMem() << endl;
	
    thrust::device_vector<unsigned int> d_res1;
    thrust::device_vector<unsigned int> d_res2;    
	unsigned int cnt_l, res_count, tot_count = 0, offset = 0, k = 0;

	queue<string> lc(cc);
	curr_segment = 10000000;			
	
	
    for (unsigned int i = 0; i < left->segCount; i++) {		
	    
		cout << "segment " << i << " " << getFreeMem() << endl;				
		cnt_l = 0;
		
		if (left->type[colInd1]  != 2) {
		    copyColumns(left, lc, i, cnt_l);
		}
        else {
            left->add_hashed_strings(colInd1, i);
        };		
		
		
        if(left->prm.empty()) {
           //copy all records	    
		    cnt_l = left->mRecCount;
        }			
		else {				    	 		
			cnt_l = left->prm_count[i];
		};			
		
		if (cnt_l) { 					        

			unsigned int idx;
			if(!str_join)
                idx = left->type_index[colInd1];
            else
                idx = left->d_columns_int.size()-1;				
					
			//cout << "cnts " << cnt_l << " " << cnt_r << endl;	

            //for(int z = 0; z < 50; z++)
			//cout << "L R " << left->d_columns_int[idx][z] << " " << right->d_columns_int[right->type_index[colInd2]][z] << endl;

			
            join(thrust::raw_pointer_cast(right->d_columns_int[right->type_index[colInd2]].data()), thrust::raw_pointer_cast(left->d_columns_int[idx].data()),
                 d_res1, d_res2, cnt_l, cnt_r, right->isUnique(colInd2));
		
    	    res_count = d_res1.size();
			cout << "res count " << res_count << endl;
			tot_count = tot_count + res_count;

            if(res_count) {		 				
                
    		    offset = c->mRecCount;
		        c->resize(res_count);					
	            queue<string> op_sel1(op_sel);					

                while(!op_sel1.empty()) {

                    while(!cc.empty())
                        cc.pop();
						
                    cc.push(op_sel1.front());
				
                    if(left->columnNames.find(op_sel1.front()) !=  left->columnNames.end()) {
					    // copy field's segment to device, gather it and copy to the host  
				        unsigned int colInd = left->columnNames[op_sel1.front()];	
                        allocColumns(left, cc);	
				        copyColumns(left, cc, i, k);
						
				       //gather	   
				        if(left->type[colInd] == 0) {
                            thrust::permutation_iterator<ElementIterator_int,IndexIterator> iter(left->d_columns_int[left->type_index[colInd]].begin(), d_res1.begin());
							thrust::copy(iter, iter + res_count, c->h_columns_int[c->type_index[c->columnNames[op_sel1.front()]]].begin() + offset);								   
				        }	   
					    else if(left->type[colInd] == 1) {
                            thrust::permutation_iterator<ElementIterator_float,IndexIterator> iter(left->d_columns_float[left->type_index[colInd]].begin(), d_res1.begin());
  					        thrust::copy(iter, iter + res_count, c->h_columns_float[c->type_index[c->columnNames[op_sel1.front()]]].begin() + offset);												   						   							   
					    }
                        else { //strings
                            thrust::device_ptr<char> d_tmp = thrust::device_malloc<char>(res_count*left->char_size[left->type_index[colInd]]);			
                            str_gather(thrust::raw_pointer_cast(d_res1.data()), res_count, (void*)left->d_columns_char[left->type_index[colInd]],
							                                    (void*) thrust::raw_pointer_cast(d_tmp), left->char_size[left->type_index[colInd]]);
                            cudaMemcpy( (void*)&c->h_columns_char[c->type_index[colInd]][offset*c->char_size[c->type_index[colInd]]], (void*) thrust::raw_pointer_cast(d_tmp), 
						                 left->char_size[left->type_index[colInd]] * res_count, cudaMemcpyDeviceToHost);		            
                            thrust::device_free(d_tmp); 	
                        }						  

					}
                    else {
					    unsigned int colInd = right->columnNames[op_sel1.front()];		
					    //gather	   					   
					    if(right->type[colInd] == 0) {
                            thrust::permutation_iterator<ElementIterator_int,IndexIterator> iter(right->d_columns_int[right->type_index[colInd]].begin(), d_res2.begin());
                            thrust::copy(iter, iter + res_count, c->h_columns_int[c->type_index[c->columnNames[op_sel1.front()]]].begin() + offset);								   
					     }
  				        else if(right->type[colInd] == 1) {
                            thrust::permutation_iterator<ElementIterator_float,IndexIterator> iter(right->d_columns_float[right->type_index[colInd]].begin(), d_res2.begin());
  					        thrust::copy(iter, iter + res_count, c->h_columns_float[c->type_index[c->columnNames[op_sel1.front()]]].begin() + offset);												   						   							   
					    }
                        else { //strings
                            thrust::device_ptr<char> d_tmp = thrust::device_malloc<char>(res_count*right->char_size[right->type_index[colInd]]);			
                            str_gather(thrust::raw_pointer_cast(d_res2.data()), res_count, (void*)right->d_columns_char[right->type_index[colInd]], (void*) thrust::raw_pointer_cast(d_tmp), right->char_size[right->type_index[colInd]]);
                            cudaMemcpy( (void*)&c->h_columns_char[c->type_index[colInd]][offset*c->char_size[c->type_index[colInd]]], (void*) thrust::raw_pointer_cast(d_tmp), 
						                right->char_size[right->type_index[colInd]] * res_count, cudaMemcpyDeviceToHost);		            
                            thrust::device_free(d_tmp); 							   
                        }						  
						   
					};
                    op_sel1.pop();		  
                };	
			};	
        };
    };	

			
    d_res1.resize(0);
    d_res1.shrink_to_fit();
    d_res2.resize(0);
    d_res2.shrink_to_fit();	   	
		
    left->deAllocOnDevice();	
    right->deAllocOnDevice();
	c->deAllocOnDevice();	
	
	cout << "join final end " << tot_count << "  " << getFreeMem() << endl;

    varNames[s] = c;
	c->mRecCount = tot_count; 
    for ( map<string,int>::iterator it=c->columnNames.begin() ; it != c->columnNames.end(); ++it )
        setMap[(*it).first] = s;

    clean_queues();


    if(stat[s] == statement_count) {
        c->free();
        varNames.erase(s);
    };

    if(stat[j1] == statement_count) {
        left->free();
        varNames.erase(j1);
    };

    if(stat[j2] == statement_count && (strcmp(j1,j2.c_str()) != 0)) {
        right->free();
        varNames.erase(j2);
    };

    std::cout<< "join time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) <<'\n';		

}


void order_on_host(CudaSet *a, CudaSet* b, queue<string> names, stack<string> exe_type, stack<string> exe_value)
{
    unsigned int tot = 0;
    if(!a->not_compressed) { //compressed
        allocColumns(a, names);
		
		unsigned int c = 0;
       	if(a->prm_count.size())	{	
            for(unsigned int i = 0; i < a->prm.size(); i++)
                c = c + a->prm_count[i];
		}
        else
            c = a->mRecCount;			
		a->mRecCount = 0;	
	    a->resize(c);
			
		unsigned int cnt = 0;
		for(unsigned int i = 0; i < a->segCount; i++) {		
            copyColumns(a, names, (a->segCount - i) - 1, cnt);	//uses segment 1 on a host	to copy data from a file to gpu			
			if (a->mRecCount) {
                a->CopyToHost((c - tot) - a->mRecCount, a->mRecCount);			
			    tot = tot + a->mRecCount;		
			};	
		};
	}
	else
	    tot = a->mRecCount;
	
	
    b->resize(tot); //resize host arrays	
	a->mRecCount = tot;		
	
	
	unsigned int* permutation = new unsigned int[a->mRecCount];
	thrust::sequence(permutation, permutation + a->mRecCount);

	unsigned int maxSize =  a->mRecCount;
	char* temp;
	unsigned int max_char = 0;
	for(unsigned int i = 0; i < a->char_size.size(); i++)
		if (a->char_size[a->type_index[i]] > max_char)
			max_char = a->char_size[a->type_index[i]];			

	if(max_char > float_size)	
		temp = new char[maxSize*max_char];
	else	
		temp = new char[maxSize*float_size];    
	
	// sort on host
	
	for(int i=0; !exe_type.empty(); ++i, exe_type.pop(),exe_value.pop()) {
		int colInd = (a->columnNames).find(exe_type.top())->second;

		if ((a->type)[colInd] == 0)
			update_permutation_host(a->h_columns_int[a->type_index[colInd]].data(), permutation, a->mRecCount, exe_value.top(), (int_type*)temp);
		else if ((a->type)[colInd] == 1)
			update_permutation_host(a->h_columns_float[a->type_index[colInd]].data(), permutation, a->mRecCount,exe_value.top(), (float_type*)temp);
		else {
			update_permutation_char_host(a->h_columns_char[a->type_index[colInd]], permutation, a->mRecCount, exe_value.top(), b->h_columns_char[b->type_index[colInd]], a->char_size[a->type_index[colInd]]);	
		};
	};
	
	
	for (unsigned int i = 0; i < a->mColumnCount; i++) {
		if ((a->type)[i] == 0) {
			apply_permutation_host(a->h_columns_int[a->type_index[i]].data(), permutation, a->mRecCount, b->h_columns_int[b->type_index[i]].data());
		}	
		else if ((a->type)[i] == 1)
			apply_permutation_host(a->h_columns_float[a->type_index[i]].data(), permutation, a->mRecCount, b->h_columns_float[b->type_index[i]].data());
		else {
			apply_permutation_char_host(a->h_columns_char[a->type_index[i]], permutation, a->mRecCount, b->h_columns_char[b->type_index[i]], a->char_size[a->type_index[i]]);
		};
	};
	
	delete [] temp;
	delete [] permutation;

}



void emit_order(char *s, char *f, int e, int ll)
{
    if(ll == 0)
        statement_count++;

    if (scan_state == 0 && ll == 0) {
        if (stat.find(f) == stat.end()) {
            cout << "Order : couldn't find variable " << f << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[f] = statement_count;
        return;
    };

    if(varNames.find(f) == varNames.end() ) {
        clean_queues();
        return;
    };


    CudaSet* a = varNames.find(f)->second;


    if (a->mRecCount == 0)	{
        if(varNames.find(s) == varNames.end())
            varNames[s] = new CudaSet(0,1);
        else {
            CudaSet* c = varNames.find(s)->second;
            c->mRecCount = 0;
        };
        return;
    };

    stack<string> exe_type, exe_value;

    cout << "order: " << s << " " << f << endl;;


    for(int i=0; !op_type.empty(); ++i, op_type.pop(),op_value.pop()) {
        if ((op_type.front()).compare("NAME") == 0) {
            exe_type.push(op_value.front());
            exe_value.push("ASC");
        }
        else {
            exe_type.push(op_type.front());
            exe_value.push(op_value.front());
        };
    };
	
    stack<string> tp(exe_type);
    queue<string> op_vx;
    while (!tp.empty()) {
        op_vx.push(tp.top());
        tp.pop();
    };
	
	queue<string> names;
	for ( map<string,int>::iterator it=a->columnNames.begin() ; it != a->columnNames.end(); ++it )
	    names.push((*it).first);

	CudaSet *b = a->copyDeviceStruct();
	
	//lets find out if our data set fits into a GPU
	size_t mem_available = getFreeMem();
	size_t rec_size = 0;
	for(unsigned int i = 0; i < a->mColumnCount; i++) {
        if(a->type[i] == 0)
            rec_size = rec_size + int_size;         
		else if(a->type[i] == 1)	
	        rec_size = rec_size + float_size;         
		else 	
           rec_size = rec_size + a->char_size[a->type_index[i]];
    };	
	bool fits = 1;
	if (rec_size*a->mRecCount > (mem_available/2)) // doesn't fit into a GPU
	    fits = 0;
		
		
	fits = 0; //for a test	
	if(!fits) {
	    order_on_host(a, b, names, exe_type, exe_value);
	}	
	else {
	    // initialize permutation to [0, 1, 2, ... ,N-1]
		thrust::device_ptr<unsigned int> permutation = thrust::device_malloc<unsigned int>(a->mRecCount);
		thrust::sequence(permutation, permutation+(a->mRecCount));

		unsigned int* raw_ptr = thrust::raw_pointer_cast(permutation);

		unsigned int maxSize =  a->mRecCount;
		void* temp;
		unsigned int max_char = 0;
		for(unsigned int i = 0; i < a->char_size.size(); i++)
			if (a->char_size[a->type_index[i]] > max_char)
				max_char = a->char_size[a->type_index[i]];			
	
		if(max_char > float_size)	
			CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*max_char));
		else	
			CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*float_size));    

		varNames[setMap[exe_type.top()]]->oldRecCount = varNames[setMap[exe_type.top()]]->mRecCount;
	
	
		unsigned int rcount;
		a->mRecCount = load_queue(names, a, 1, op_vx.front(), rcount);	
    
		varNames[setMap[exe_type.top()]]->mRecCount = varNames[setMap[exe_type.top()]]->oldRecCount;

		for(int i=0; !exe_type.empty(); ++i, exe_type.pop(),exe_value.pop()) {
			int colInd = (a->columnNames).find(exe_type.top())->second;

			if ((a->type)[colInd] == 0)
				update_permutation(a->d_columns_int[a->type_index[colInd]], raw_ptr, a->mRecCount, exe_value.top(), (int_type*)temp);
			else if ((a->type)[colInd] == 1)
				update_permutation(a->d_columns_float[a->type_index[colInd]], raw_ptr, a->mRecCount,exe_value.top(), (float_type*)temp);
			else {
				update_permutation_char(a->d_columns_char[a->type_index[colInd]], raw_ptr, a->mRecCount, exe_value.top(), (char*)temp, a->char_size[a->type_index[colInd]]);	
			};
		};
		
        b->resize(a->mRecCount); //resize host arrays	
	    b->mRecCount = a->mRecCount;		
	
		for (unsigned int i = 0; i < a->mColumnCount; i++) {
			if ((a->type)[i] == 0)
				apply_permutation(a->d_columns_int[a->type_index[i]], raw_ptr, a->mRecCount, (int_type*)temp);
			else if ((a->type)[i] == 1)
				apply_permutation(a->d_columns_float[a->type_index[i]], raw_ptr, a->mRecCount, (float_type*)temp);
			else {
				apply_permutation_char(a->d_columns_char[a->type_index[i]], raw_ptr, a->mRecCount, (char*)temp, a->char_size[a->type_index[i]]);
			};
		};	
		
		for(unsigned int i = 0; i < a->mColumnCount; i++) {
			switch(a->type[i]) {		 
			case 0 :
				thrust::copy(a->d_columns_int[a->type_index[i]].begin(), a->d_columns_int[a->type_index[i]].begin() + a->mRecCount, b->h_columns_int[b->type_index[i]].begin());
				break;
			case 1 :
				thrust::copy(a->d_columns_float[a->type_index[i]].begin(), a->d_columns_float[a->type_index[i]].begin() + a->mRecCount, b->h_columns_float[b->type_index[i]].begin());
				break;
			default :
				cudaMemcpy(b->h_columns_char[b->type_index[i]], a->d_columns_char[a->type_index[i]], a->char_size[a->type_index[i]]*a->mRecCount, cudaMemcpyDeviceToHost);
			}
		};

		b->deAllocOnDevice();
		a->deAllocOnDevice();


		thrust::device_free(permutation);
		cudaFree(temp);
	};	

    varNames[s] = b;
    b->segCount = 1;
    b->not_compressed = 1;

    if(stat[f] == statement_count && !a->keep) {
        a->free();
        varNames.erase(f);
    };
}


void emit_select(char *s, char *f, int ll)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(f) == stat.end()) {
            cout << "Select : couldn't find variable " << f << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[f] = statement_count;
        return;
    };


    if(varNames.find(f) == varNames.end()) {
        clean_queues();
        return;
    };



    queue<string> op_v1(op_value);
    while(op_v1.size() > ll)
        op_v1.pop();


    stack<string> op_v2;
    queue<string> op_v3;

    for(int i=0; i < ll; ++i) {
        op_v2.push(op_v1.front());
        op_v3.push(op_v1.front());
        op_v1.pop();
    };


    CudaSet *a;
    a = varNames.find(f)->second;


    if(a->mRecCount == 0) {
        CudaSet *c;
        c = new CudaSet(0,1);
        varNames[s] = c;
        clean_queues();
        return;
    };

    cout << "SELECT " << s << " " << f << endl;
    std::clock_t start1 = std::clock();

	unordered_map<long long int, unsigned int> mymap; 
    // here we need to determine the column count and composition

    queue<string> op_v(op_value);
    queue<string> op_vx;
    set<string> field_names;
    map<string,string> aliases;
    string tt;

    for(int i=0; !op_v.empty(); ++i, op_v.pop()) {
        if(a->columnNames.find(op_v.front()) != a->columnNames.end()) {
            field_names.insert(op_v.front());
            if(aliases.count(op_v.front()) == 0 && aliases.size() < ll) {
                tt = op_v.front();
                op_v.pop();
                aliases[tt] = op_v.front();
            };

        };
    };


    for (set<string>::iterator it=field_names.begin(); it!=field_names.end(); ++it)  {
        op_vx.push(*it);
    };

    // find out how many columns a new set will have
    queue<string> op_t(op_type);
    int_type col_count = 0;

    for(int i=0; !op_t.empty(); ++i, op_t.pop())
        if((op_t.front()).compare("emit sel_name") == 0)
            col_count++;

    CudaSet *b, *c;

	curr_segment = 10000000;
    allocColumns(a, op_vx);
	
	unsigned int cycle_count;
	if(!a->prm.empty())
        cycle_count = varNames[setMap[op_value.front()]]->segCount;
	else
        cycle_count = a->segCount;	
    
    unsigned int ol_count = a->mRecCount, cnt;
    //varNames[setMap[op_value.front()]]->oldRecCount = varNames[setMap[op_value.front()]]->mRecCount;
	a->oldRecCount = a->mRecCount;
	b = new CudaSet(0, col_count);	
	bool b_set = 0, c_set = 0;
	
    for(unsigned int i = 0; i < cycle_count; i++) {          // MAIN CYCLE
        cout << "cycle " << i << " select mem " << getFreeMem() << endl;
                   
		cnt = 0;		
        copyColumns(a, op_vx, i, cnt);	
		
        if(a->mRecCount) { 			

            if (ll != 0) {
                order_inplace(a,op_v2,field_names,i);
                a->GroupBy(op_v3);
            };
            select(op_type,op_value,op_nums, op_nums_f,a,b, a->mRecCount);		
		
            if(!b_set) {
                for ( map<string,int>::iterator it=b->columnNames.begin() ; it != b->columnNames.end(); ++it )
                    setMap[(*it).first] = s;
				b_set = 1;	
				unsigned int old_cnt = b->mRecCount;
				b->mRecCount = 0;
				b->resize(varNames[setMap[op_vx.front()]]->maxRecs);
				b->mRecCount = old_cnt;
            };

            if (ll != 0) {
                if (!c_set) {
                    c = new CudaSet(0, col_count);
                    c->not_compressed = 1;
                    c->segCount = 1;
					c_set = 1;
                }
                add(c,b,op_v3, mymap, aliases);
            };
		};	
    };
	
	

    a->mRecCount = ol_count;
    //varNames[setMap[op_value.front()]]->mRecCount = varNames[setMap[op_value.front()]]->oldRecCount;
	a->mRecCount = a->oldRecCount;
    a->deAllocOnDevice();

    if (ll != 0) {
        count_avg(c);
    };

    //c->deAllocOnDevice();
    c->maxRecs = c->mRecCount;
    c->name = s;
    c->keep = 1;

    for ( map<string,int>::iterator it=c->columnNames.begin() ; it != c->columnNames.end(); ++it ) {
        setMap[(*it).first] = s;
    };

    cout << "final select " << c->mRecCount << endl;

    clean_queues();

    if (ll != 0) {
        varNames[s] = c;
        b->free();
    }
    else
        varNames[s] = b;

    varNames[s]->keep = 1;

    if(stat[s] == statement_count) {
        varNames[s]->free();
        varNames.erase(s);
    };

    if(stat[f] == statement_count && a->keep == 0) {
        a->free();
        varNames.erase(f);
    };
    std::cout<< "select time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) <<'\n';
}


void emit_filter(char *s, char *f, int e)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(f) == stat.end()) {
            cout << "Filter : couldn't find variable " << f << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[f] = statement_count;
        clean_queues();
        return;
    };


    if(varNames.find(f) == varNames.end()) {
        clean_queues();
        return;
    };

    CudaSet *a, *b;

    a = varNames.find(f)->second;
    a->name = f;
    std::clock_t start1 = std::clock();

    if(a->mRecCount == 0) {
        b = new CudaSet(0,1);
    }
    else {
        cout << "FILTER " << s << " " << f << " " << getFreeMem() << endl;
		

        b = a->copyDeviceStruct();
        b->name = s;

        unsigned int cycle_count = 1, cnt = 0;
        allocColumns(a, op_value);
		
        varNames[setMap[op_value.front()]]->oldRecCount = varNames[setMap[op_value.front()]]->mRecCount;

        if(a->segCount != 1)
            cycle_count = varNames[setMap[op_value.front()]]->segCount;
        
		oldCount = a->mRecCount;
        thrust::device_vector<unsigned int> p(a->maxRecs);


        for(unsigned int i = 0; i < cycle_count; i++) {		 
        	map_check = zone_map_check(op_type,op_value,op_nums, op_nums_f, a, i);
	        cout << "MAP CHECK " << map_check << endl;		
            if(map_check == 'R') {			
                copyColumns(a, op_value, i, cnt);
                filter(op_type,op_value,op_nums, op_nums_f,a, b, i, p);
			}
            else  {		
				setPrm(a,b,map_check,i);
			}
        };
		a->mRecCount = oldCount;
        varNames[setMap[op_value.front()]]->mRecCount = varNames[setMap[op_value.front()]]->oldRecCount;
        cout << "filter is finished " << b->mRecCount << " " << getFreeMem()  << endl;             
        a->deAllocOnDevice();
    };

    clean_queues();

    if (varNames.count(s) > 0)
        varNames[s]->free();

    varNames[s] = b;

    if(stat[s] == statement_count) {
        b->free();
        varNames.erase(s);
    };
    if(stat[f] == statement_count && !a->keep) {
        a->free();
        varNames.erase(f);
    };
    std::cout<< "filter time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) << " " << getFreeMem() << '\n';
}

void emit_store(char *s, char *f, char* sep)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(s) == stat.end()) {
            cout << "Store : couldn't find variable " << s << endl;
            exit(1);
        };
        stat[s] = statement_count;
        return;
    };


    if(varNames.find(s) == varNames.end())
        return;

    CudaSet* a = varNames.find(s)->second;

    cout << "STORE: " << s << " " << f << " " << sep << endl;


    int limit = 0;
    if(!op_nums.empty()) {
        limit = op_nums.front();
        op_nums.pop();
    };

    a->Store(f,sep, limit, 0);

    if(stat[s] == statement_count  && a->keep == 0) {
        a->free();
        varNames.erase(s);
    };


};


void emit_store_binary(char *s, char *f)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(s) == stat.end()) {
            cout << "Store : couldn't find variable " << s << endl;
            exit(1);
        };
        stat[s] = statement_count;
        return;
    };


    if(varNames.find(s) == varNames.end())
        return;

    CudaSet* a = varNames.find(s)->second;

    if(stat[f] == statement_count)
        a->deAllocOnDevice();


    printf("STORE: %s %s \n", s, f);

    int limit = 0;
    if(!op_nums.empty()) {
        limit = op_nums.front();
        op_nums.pop();
    };
	total_count = 0;
    total_segments = 0;
    fact_file_loaded = 0;	

    while(!fact_file_loaded)	{
        cout << "LOADING " << f_file << " " << separator << endl;
		if(a->text_source)
            fact_file_loaded = a->LoadBigFile(f_file.c_str(), separator.c_str());
        a->Store(f,"", limit, 1);
    };

    if(stat[f] == statement_count && !a->keep) {
        a->free();
        varNames.erase(s);
    };

};



void emit_load_binary(char *s, char *f, int d)
{
    statement_count++;
    if (scan_state == 0) {
        stat[s] = statement_count;
        return;
    };

    printf("BINARY LOAD: %s %s \n", s, f);

    CudaSet *a;
    unsigned int segCount, maxRecs;
    char f1[100];
    strcpy(f1, f);
    strcat(f1,".");
    char col_pos[3];
    itoaa(cols.front(),col_pos);
    strcat(f1,col_pos);
	strcat(f1,".header");

    FILE* ff = fopen(f1, "rb");
    fread((char *)&totalRecs, 8, 1, ff);
    fread((char *)&segCount, 4, 1, ff);
    fread((char *)&maxRecs, 4, 1, ff);
    fclose(ff);

    queue<string> names(namevars);
    while(!names.empty()) {
        setMap[names.front()] = s;
        names.pop();
    };

    a = new CudaSet(namevars, typevars, sizevars, cols,totalRecs, f);
    a->segCount = segCount;
    a->maxRecs = maxRecs;
    a->keep = 1;
    varNames[s] = a;

    if(stat[s] == statement_count )  {
        a->free();
        varNames.erase(s);
    };
}





void emit_load(char *s, char *f, int d, char* sep)
{
    statement_count++;
    if (scan_state == 0) {
        stat[s] = statement_count;
        return;
    };


    printf("LOAD: %s %s %d  %s \n", s, f, d, sep);

    CudaSet *a;

    a = new CudaSet(namevars, typevars, sizevars, cols, process_count);
    a->mRecCount = 0;
    a->resize(process_count);
    a->keep = true;
    a->not_compressed = 1;
    
    string separator1(sep);
    separator = separator1;
    string ff(f);
    f_file = ff;
    a->maxRecs = a->mRecCount;
    a->segCount = 0;
    varNames[s] = a;

    if(stat[s] == statement_count)  {
        a->free();
        varNames.erase(s);
    };

}



void yyerror(char *s, ...)
{
    extern int yylineno;
    va_list ap;
    va_start(ap, s);

    fprintf(stderr, "%d: error: ", yylineno);
    vfprintf(stderr, s, ap);
    fprintf(stderr, "\n");
}

void clean_queues()
{
    while(!op_type.empty()) op_type.pop();
    while(!op_value.empty()) op_value.pop();
    while(!op_join.empty()) op_join.pop();
    while(!op_nums.empty()) op_nums.pop();
    while(!op_nums_f.empty()) op_nums_f.pop();
    while(!j_col_count.empty()) j_col_count.pop();
    while(!namevars.empty()) namevars.pop();
    while(!typevars.empty()) typevars.pop();
    while(!sizevars.empty()) sizevars.pop();
    while(!cols.empty()) cols.pop();

    sel_count = 0;
    join_cnt = 0;
    join_col_cnt = -1;
    eqq = 0;
}



int main(int ac, char **av)
{
    extern FILE *yyin;	
    //cudaDeviceProp deviceProp;

    //cudaGetDeviceProperties(&deviceProp, 0);
    //if (!deviceProp.canMapHostMemory)
    //    cout << "Device 0 cannot map host memory" << endl;

    //cudaSetDeviceFlags(cudaDeviceMapHost);
    //cudppCreate(&theCudpp);

    if (ac == 1) {
        cout << "Usage : alenka -l process_count script.sql" << endl;
        exit(1);
    };

    if(strcmp(av[1],"-l") == 0) {
        process_count = atoff(av[2]);
        cout << "Process count = " << process_count << endl;
    }
    else {
        process_count = 6200000;
        cout << "Process count = 6200000 " << endl;
    };

    if((yyin = fopen(av[ac-1], "r")) == NULL) {
        perror(av[ac-1]);
        exit(1);
    };

    if(yyparse()) {
        printf("SQL scan parse failed\n");
        exit(1);
    };
    
    scan_state = 1;

    std::clock_t start1 = std::clock();
    statement_count = 0;
    clean_queues();

    if(ac > 1 && (yyin = fopen(av[ac-1], "r")) == NULL) {
        perror(av[1]);
        exit(1);
    }

    PROC_FLUSH_BUF ( yyin );
    statement_count = 0;

    if(!yyparse())
        cout << "SQL scan parse worked" << endl;
    else
        cout << "SQL scan parse failed" << endl;

    fclose(yyin);
    std::cout<< "cycle time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) <<'\n';
    //cudppDestroy(theCudpp);

}


