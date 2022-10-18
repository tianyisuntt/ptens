#ifndef _ptens_Ptensor0
#define _ptens_Ptensor0

#include "Ptens_base.hpp"
#include "Atoms.hpp"
#include "RtensorA.hpp"
#include "RtensorObj.hpp"
//#include "PtensorSgntr.hpp"


namespace ptens{

  class Ptensor0: public cnine::RtensorA{
  public:


    typedef cnine::Gdims Gdims;
    typedef cnine::RtensorA rtensor;
    typedef cnine::Rtensor1_view Rtensor1_view;

    int k;
    int nc;
    Atoms atoms;

    #ifdef WITH_FAKE_GRAD
    Ptensor0* grad=nullptr;
    #endif 


    ~Ptensor0(){
      #ifdef WITH_FAKE_GRAD
      if(!is_view) delete grad;
      #endif 
    }


    // ---- Constructors -------------------------------------------------------------------------------------


    template<typename FILLTYPE, typename = typename std::enable_if<std::is_base_of<cnine::fill_pattern, FILLTYPE>::value, FILLTYPE>::type>
    Ptensor0(const Atoms& _atoms, const int _nc, const FILLTYPE& dummy, const int _dev=0):
      rtensor(cnine::Gdims(_nc),dummy,_dev),
      atoms(_atoms),
      k(_atoms.size()), 
      nc(_nc){
    }

    //template<typename FILLTYPE, typename = typename std::enable_if<std::is_base_of<cnine::fill_pattern, FILLTYPE>::value, FILLTYPE>::type>
    //Ptensor0(const int _k, const int _nc, const FILLTYPE& dummy, const int _dev=0):
    //rtensor(cnine::Gdims(_nc),dummy,_dev),
    //atoms(_atoms),
    //k(_k), 
    //nc(_nc){
    //}


    // ---- Constructors -------------------------------------------------------------------------------------
    

    static Ptensor0 raw(const Atoms& _atoms, const int nc=1, const int _dev=0){
      return Ptensor0(_atoms,nc,cnine::fill_raw(),_dev);}

    static Ptensor0 zero(const Atoms& _atoms, const int nc=1, const int _dev=0){
      return Ptensor0(_atoms,nc,cnine::fill_zero(),_dev);}

    static Ptensor0 gaussian(const Atoms& _atoms, const int nc=1, const int _dev=0){
      return Ptensor0(_atoms,nc,cnine::fill_gaussian(),_dev);}

    static Ptensor0 gaussian(const Atoms& _atoms, const int nc, const float sigma, const int _dev){
      return Ptensor0(_atoms,nc,cnine::fill_gaussian(sigma),_dev);}

    static Ptensor0 sequential(const Atoms& _atoms, const int nc, const int _dev=0){
      return Ptensor0(_atoms,nc,cnine::fill_sequential(),_dev);}

    
    // ---- Copying ------------------------------------------------------------------------------------------


    Ptensor0(const Ptensor0& x):
      RtensorA(x), atoms(x.atoms){
      k=x.k;
      nc=x.nc;
    }

    Ptensor0(Ptensor0&& x):
      RtensorA(std::move(x)), atoms(std::move(x.atoms)){
      k=x.k;
      nc=x.nc;
    }

    Ptensor0& operator=(const Ptensor0& x)=delete;


    // ---- Conversions --------------------------------------------------------------------------------------


    Ptensor0(RtensorA&& x, Atoms&& _atoms):
      RtensorA(std::move(x)),
      atoms(std::move(_atoms)){
      assert(x.getk()==1);
      k=dims(0);
      nc=dims.back();
    }

    #ifdef _WITH_ATEN
    static Ptensor0 view(at::Tensor& x, Atoms&& _atoms){
      return Ptensor0(RtensorA::view(x),std::move(_atoms));
    }
    #endif 


    // ---- Access -------------------------------------------------------------------------------------------


    int getk() const{
      return dims(0);
    }

    int get_nc() const{
      return dims.back();
    }

    vector<int> atomsv() const{
      return atoms;
    }

    float at_(const int i, const int c) const{
      return (*this)(atoms(i),c);
    }

    void inc_(const int i, const int c, float x){
      inc(atoms(i),c,x);
    }


    Rtensor1_view view() const{
      return view1();
    }

    Rtensor1_view view(const int offs, const int n) const{
      assert(offs+n<=nc);
      return view1().block(offs,n);
    }


  public: // ---- Linmaps -------------------------------------------------------------------------------------


    // 0 -> 0
    void add_linmaps(const Ptensor0& x, int offs=0){ // 1 
      assert(offs+1*x.nc<=nc);
      offs+=broadcast0(x,offs); // 1*1
    }

    void add_linmaps_back(const Ptensor0& x, int offs=0){ // 1 
      assert(offs+1*nc<=x.nc);
      broadcast0(x.reduce0(offs,nc));
    }
    


  public: // ---- Reductions ---------------------------------------------------------------------------------


    rtensor reduce0() const{
      auto R=rtensor::zero(Gdims(nc));
      R.view1().add(view());
      return R;
    }

    rtensor reduce0(const int offs, const int n) const{
      auto R=rtensor::zero(Gdims(n));
      R.view1().add(view(offs,n));
      return R;
    }

    rtensor reduce0(const vector<int>& ix) const{
      assert(ix.size()==1);
      auto R=rtensor::zero(Gdims(nc));
      R.view1()+=view();
      return R;
    }

    rtensor reduce0(const vector<int>& ix, const int offs, const int n) const{
      assert(ix.size()==1);
      auto R=rtensor::zero(Gdims(n));
      R.view1()+=view(offs,n);
      return R;
    }


  public: // ---- Broadcasting -------------------------------------------------------------------------------


    void broadcast0(const rtensor& x){
      view(0,x.dim(0))+=x.view1();
    }

    int broadcast0(const rtensor& x, const int offs){
      view(offs,x.dim(0))+=x.view1();
      return x.dim(0);
    }

    void broadcast0(const rtensor& x, const vector<int>& ix){
      assert(ix.size()==1);
      view(0,x.dim(0))+=x.view1();
    }

    void broadcast0(const rtensor& x, const vector<int>& ix, const int offs){
      assert(ix.size()==1);
      view(offs,x.dim(0))+=x.view1();
    }




  private: // ---- Broadcasting -------------------------------------------------------------------------------
    // These methods are deprectated / on hold 

    void broadcast0(const Rtensor1_view& x){
      view()+=x;
    }

    int broadcast0(const Rtensor1_view& x, const int offs){
      view(offs,x.n0)+=x;
      return x.n0;
    }


  public: // ---- I/O ----------------------------------------------------------------------------------------


    string str(const string indent="")const{
      ostringstream oss;
      oss<<indent<<"Ptensor0 "<<atoms<<":"<<endl;
      oss<<rtensor::str(indent);
      return oss.str();
    }

    friend ostream& operator<<(ostream& stream, const Ptensor0& x){
      stream<<x.str(); return stream;}

  };

}


#endif 

    //PtensorSgntr signature() const{
    //return PtensorSgntr(getk(),get_nc());
    //}

    /*
    Ptensor0(const Ptensor0& x, const Atoms& _atoms):
      Ptensor0(_atoms,5*x.get_nc(),cnine::fill_zero()){
      pull_msg(x);
    }


    void pull_msg(const Ptensor0& x){
      int nc=x.get_nc();
      assert(get_nc()==5*nc);

      Atoms common=atoms.intersect(x.atoms);
      int k=common.size();
      vector<int> ix(atoms(common));
      vector<int> xix(x.atoms(common));

      for(int j=0; j<nc; j++){

	float s=0;
	for(int i=0; i<dims[0]; i++)
	  s+=x(i,j);
     
	float t=0;
	for(int i=0; i<k; i++){
	  t+=x(xix[i],j);
	}

	for(int i=0; i<k; i++){
	  inc(ix[i],5*j,x(xix[i],j));
	  inc(ix[i],5*j+1,t);
	  inc(ix[i],5*j+2,s);
	}

	for(int i=0; i<dims[0]; i++){
	  inc(i,5*j+3,t);
	  inc(i,5*j+4,s);
	}

      }

    }
    */
    /*
    rtensor reductions0(const vector<int>& ix, const int c) const{
      const int n=dim(0);
      const int k=ix.size();
      rtensor R=rtensor::raw(cnine::Gdims(get_nc()));
      for(int i=0; i<
      {float t=0; for(int i=0; i<k; i++) t+=(*this)(ix[i],c); R.set(0,t);}
      {float t=0; for(int i=0; i<n; i++) t+=(*this)(i,c); R.set(1,t);}
      return R;
    }
    */
    /*
   void broadcast0(const rtensor& R0, const vector<int>& ix, int coffs){
     assert(R0.ndims()==1);

      for(int c=0; c<R0.dim(0); c++){
	inc(coffs,R0(s));
	coffs+=2;
      }
    }
    */
