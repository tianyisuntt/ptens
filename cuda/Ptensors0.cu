/*
This file is part of ptens, a C++/CUDA library for permutation 
equivariant message passing. 
 
Copyright (c) 2023, Imre Risi Kondor

This source code file is subject to the terms of the noncommercial 
license distributed with cnine in the file LICENSE.TXT. Commercial 
use is prohibited. All redistributed versions of this file (in 
original or modified form) must retain this copyright notice and 
must be accompanied by a verbatim copy of the license. 
*/

#ifndef _Ptensors0_cu
#define _Ptensors0_cu

#include <cuda.h>
#include <cuda_runtime.h>
#include <thrust/complex.h>
#include <thrust/tuple.h>

#include "Ptens_base.hpp"
#include "RtensorPackB.hpp"
#include "AindexPack.hpp"
#include "CSRmatrix.hpp"


__global__ void Ptensors0_reduce0_kernel(float* rarr, const int* rdir, const float* xarr, const int* xdir){
  const int i=blockIdx.x;
  const int c=threadIdx.x;
  rarr[rdir[2*i]+c]+=xarr[xdir[2*i]+c];
}


__global__ void Ptensors0_reduce0_kernel(float* rarr, const int* rdir, const float* xarr, const int* xdir, const int* xiarr, const int* xidir, const int n){
  const int b=blockIdx.x;
  const int c=threadIdx.x;
  const int src=xiarr[xidir[2*b]];
  rarr[rdir[2*b]+c]+=xarr[xdir[2*src]+c];
}


__global__ void Ptensors0_broadcast0_kernel(float* xarr, const int* xdir, const float* rarr, const int* rdir){
  const int i=blockIdx.x;
  const int c=threadIdx.x;
  xarr[xdir[2*i]+c]+=rarr[rdir[2*i]+c];
}


__global__ void Ptensors0_broadcast0_kernel(float* xarr, const int* xdir, const int* xiarr, const int* xidir, const float* rarr, const int* rdir, const int* bmap){
  const int b=blockIdx.x;
  const int c=threadIdx.x;
  const int boffs=bmap[3*b];
  const int N=bmap[3*b+1];
  const int target=bmap[3*b+2];

  float t=0;
  for(int j=0; j<N; j++){
    const int src=bmap[boffs+2*j];
    const float w=*reinterpret_cast<const float*>(bmap+boffs+2*j+1);
    t+=w*rarr[rdir[2*src]+c];
  }
  xarr[xdir[2*target]+c]+=t;
}


__global__ void Ptensors0_gather_kernel(float* rarr, const int* rdir, const float* xarr, const int* xdir, const float* marr, const int* mdir){
  const int i=blockIdx.x;
  const int c=threadIdx.x;

  const int moffs=mdir[2*i];
  const int N=mdir[2*i+1]/2;
  float t=0;
  for(int j=0; j<N; j++){
    const int jix=*reinterpret_cast<const int*>(marr+moffs+2*j);
    const int jweight=marr[moffs+2*j+1];
    t+=jweight*xarr[xdir[2*jix]+c];
  }
  rarr[rdir[2*i]+c]+=t;
}


// ---- Outer -----------------------------------------------------------------------------------------------


__global__ void Ptensors0_add_outer_kernel(float* rarr, const int* rdir, const float* xarr, const int* xdir, const float* yarr, const int* ydir){
  const int q=blockIdx.x;
  const int xc=threadIdx.x;
  const int yc=threadIdx.y;
  const int rc=xc*ydir[2*q+1]+yc;

  rarr[rdir[2*q]+rc]+=yarr[ydir[2*q]+yc]*xarr[xdir[2*q]+xc];
}


__global__ void Ptensors0_add_outer_back0_kernel(float* xarr, const int* xdir, const float* rarr, const int* rdir, const float* yarr, const int* ydir){
  const int q=blockIdx.x;
  const int xc=threadIdx.x;
  const int rc=xc*ydir[2*q+1];
  const int nyc=ydir[2*q+1];

  const float* r=rarr+rdir[2*q]+rc;
  const float* y=yarr+ydir[2*q];

  float t=0;
  for(int yc=0; yc<nyc; yc++)
    t+=r[yc]*y[yc];
  xarr[xdir[2*q]+xc]+=t;
}


__global__ void Ptensors0_add_outer_back1_kernel(float* yarr, const int* ydir, const float* rarr, const int* rdir, const float* xarr, const int* xdir){
  const int q=blockIdx.x;
  const int yc=threadIdx.x;
  const int nxc=xdir[1*q+1];
  const int nyc=ydir[2*q+1];
  //const int nrc=rdir[2*q+1];

  float t=0;
  const float* x=xarr+xdir[3*q];
  const float* r=rarr+rdir[3*q]+yc;
  for(int xc=0; xc<nxc; xc++)
    t+=r[nyc*xc]*x[xc];
  yarr[ydir[2*q]+yc]+=t;
}


// -----------------------------------------------------------------------------------------------------------


namespace ptens{

  void Ptensors0_reduce0_cu(cnine::RtensorPackB& R, const cnine::RtensorPackB& x, int offs, int n, const cudaStream_t& stream){
    int dev=R.dev;
    PTENS_ASSRT(R.dev==1);
    PTENS_ASSRT(x.dev==1);
    if(R.size()==0) return;
    Ptensors0_reduce0_kernel<<<R.size(),n,0,stream>>>(R.arrg,R.dir.garr(dev),x.arrg+offs,x.dir.garr(dev));
  }

  void Ptensors0_reduce0_cu(cnine::RtensorPackB& R, const cnine::RtensorPackB& x, const AindexPack& list, int offs, int n, const cudaStream_t& stream){
    int dev=R.dev;
    PTENS_ASSRT(R.dev==1);
    PTENS_ASSRT(x.dev==1);
    const_cast<AindexPack&>(list).to_device(1);
    if(R.size()==0) return;
    Ptensors0_reduce0_kernel<<<R.size(),n,0,stream>>>(R.arrg,R.dir.garr(dev),x.arrg+offs,x.dir.garr(dev),list.arrg,list.dir.garr(dev),n);
  }

  void Ptensors0_broadcast0_cu(cnine::RtensorPackB& x, const cnine::RtensorPackB& R, const int offs, const cudaStream_t& stream){
    int dev=R.dev;
    PTENS_ASSRT(R.dev==1);
    PTENS_ASSRT(x.dev==1);
    if(R.size()==0) return;
    Ptensors0_broadcast0_kernel<<<R.size(),x.nc,0,stream>>>
      (x.arrg+offs,x.dir.garr(dev),R.arrg,R.dir.garr(dev));
  }

  void Ptensors0_broadcast0_cu(cnine::RtensorPackB& x, const cnine::RtensorPackB& R, const AindexPack& list, const int offs, const cudaStream_t& stream){
    int dev=R.dev;
    PTENS_ASSRT(R.dev==1);
    PTENS_ASSRT(x.dev==1);
    if(list.get_bmap().n==0) return;
    const_cast<AindexPack&>(list).to_device(1);
    Ptensors0_broadcast0_kernel<<<list.get_bmap().n,R.nc,0,stream>>>
      (x.arrg+offs,x.dir.garr(dev),list.arrg,list.dir.garr(dev),R.arrg,R.dir.garr(dev),list.get_barr(1));
  }

  void Ptensors0_gather_cu(cnine::RtensorPackB& r, const cnine::RtensorPackB& x, const cnine::CSRmatrix<float>& gmap, const cudaStream_t& stream){
    int dev=r.dev;
    PTENS_ASSRT(r.dev==1);
    PTENS_ASSRT(x.dev==1);
    if(r.size()==0) return;
    const_cast<cnine::CSRmatrix<float>&>(gmap).to_device(dev);
    Ptensors0_gather_kernel<<<r.size(),x.nc,0,stream>>>
      (r.arrg,r.dir.garr(dev),x.arrg,x.dir.garr(dev),gmap.arrg,gmap.dir.garr(dev));
  }


  void Ptensors0_add_outer_cu(cnine::RtensorPackB& r, const cnine::RtensorPackB& x, const cnine::RtensorPackB& y, 
    const cudaStream_t& stream){
    int dev=r.dev;
    PTENS_ASSRT(r.dev==1);
    PTENS_ASSRT(x.dev==1);
    PTENS_ASSRT(y.dev==1);
    dim3 threads(x.nc,y.nc);
    if(r.size()==0) return;
    Ptensors0_add_outer_kernel<<<r.size(),threads,0,stream>>>
      (r.arrg,r.dir.garr(dev),x.arrg,x.dir.garr(dev),y.arrg,y.dir.garr(dev));
  }

  void Ptensors0_add_outer_back0_cu(cnine::RtensorPackB& x, const cnine::RtensorPackB& r, const cnine::RtensorPackB& y, 
    const cudaStream_t& stream){
    int dev=r.dev;
    PTENS_ASSRT(r.dev==1);
    PTENS_ASSRT(x.dev==1);
    PTENS_ASSRT(y.dev==1);
    if(r.size()==0) return;
    Ptensors0_add_outer_back0_kernel<<<r.size(),x.nc,0,stream>>>
      (x.arrg,x.dir.garr(dev),r.arrg,r.dir.garr(dev),y.arrg,y.dir.garr(dev));
  }

  void Ptensors0_add_outer_back1_cu(cnine::RtensorPackB& y, const cnine::RtensorPackB& r, const cnine::RtensorPackB& x, 
    const cudaStream_t& stream){
    int dev=r.dev;
    PTENS_ASSRT(r.dev==1);
    PTENS_ASSRT(x.dev==1);
    PTENS_ASSRT(y.dev==1);
    if(r.size()==0) return;
    Ptensors0_add_outer_back1_kernel<<<r.size(),y.nc,0,stream>>>
      (y.arrg,y.dir.garr(dev),r.arrg,r.dir.garr(dev),x.arrg,x.dir.garr(dev));
  }


}

#endif 
