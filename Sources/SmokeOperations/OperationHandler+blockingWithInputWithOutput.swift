// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// OperationHandler+blockingWithInputWithOutput.swift
// SmokeOperations
//

import Foundation
import LoggerAPI

public extension OperationHandler {
    /**
      Initializer for blocking operation handler that has input returns
      a result body.
     
     - Parameters:
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: optionally an operation-specific delegate to use when
          handling the operation
     */
    public init<InputType: ValidatableCodable, OutputType: ValidatableCodable,
            ErrorType: ErrorIdentifiableByDescription>(
            operation: @escaping ((InputType, ContextType) throws -> OutputType),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType? = nil) {
        
        /**
         * The wrapped input handler takes the provided operation handler and wraps it so that if it
         * returns, the responseHandler is called with the result. If the provided operation
         * throws an error, the responseHandler is called with that error.
         */
        let wrappedInputHandler = { (input: InputType, request: OperationDelegateType.RequestType, context: ContextType,
                                     defaultOperationDelegate: OperationDelegateType,
                                     responseHandler: OperationDelegateType.ResponseHandlerType) in
            let operationDelegateToUse = operationDelegate ?? defaultOperationDelegate
            
            let handlerResult: WithOutputOperationHandlerResult<OutputType, ErrorType>
            do {
                let output = try operation(input, context)
                
                handlerResult = .success(output)
            } catch let smokeReturnableError as SmokeReturnableError {
                handlerResult = .smokeReturnableError(smokeReturnableError, allowedErrors)
            } catch SmokeOperationsError.validationError(reason: let reason) {
                handlerResult = .validationError(reason)
            } catch {
                handlerResult = .internalServerError(error)
            }
            
            OperationHandler.handleWithOutputOperationHandlerResult(
                handlerResult: handlerResult,
                operationDelegate: operationDelegateToUse,
                request: request,
                responseHandler: responseHandler)
        }
        
        self.init(wrappedInputHandler)
    }
}
