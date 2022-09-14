#include "Cnine_base.cpp"
#include "CnineSession.hpp"
#include "LinMaps.hpp"
#include "AddMsgFunctions.hpp"

using namespace ptens;
using namespace cnine;


int main(int argc, char** argv){

  cnine_session session;

  auto A=Ptensor1::sequential({0,1,2,3},1);
  cout<<A<<endl;
  cout<<linmaps0(A)<<endl;
  cout<<linmaps1(A)<<endl;
  cout<<linmaps2(A)<<endl;

  auto B=Ptensor1::zero({0,1,5},3);
  add_msg(B,A);
  cout<<B<<endl;

  auto C=Ptensor2::zero({0,1,5},5);
  add_msg(C,A);
  cout<<C<<endl;


}
