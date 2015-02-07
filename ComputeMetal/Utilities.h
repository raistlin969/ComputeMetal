//
//  Utilities.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/29/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#ifndef ComputeMetal_Utilities_h
#define ComputeMetal_Utilities_h

// Pipeline Error Handling ******************************************************************
static void CheckPipelineError(id<MTLRenderPipelineState> pipeline, NSError *error)
{
    if (pipeline == nil)
    {
        NSLog(@"Failed to create pipeline. error is %@", [error description]);
        assert(0);
    }
}

static void CheckPipelineError(id<MTLComputePipelineState> pipeline, NSError *error)
{
    if (pipeline == nil)
    {
        NSLog(@"Failed to create pipeline. error is %@", [error description]);
        assert(0);
    }
}

//Shader Loading ***************************************************************
static id<MTLFunction> _newFunctionFromLibrary(id<MTLLibrary> library, NSString *name)
{
    id<MTLFunction> func = [library newFunctionWithName: name];
    if (!func)
    {
        NSLog(@"failed to find function %@ in the library", name);
        assert(0);
    }
    return func;
}


#endif
