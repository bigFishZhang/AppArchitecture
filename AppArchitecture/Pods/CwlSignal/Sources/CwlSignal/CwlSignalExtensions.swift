//
//  CwlSignalExtensions.swift
//  CwlSignal
//
//  Created by Matt Gallagher on 2016/08/04.
//  Copyright © 2016 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

import Foundation

#if SWIFT_PACKAGE
	import CwlUtils
#endif

// All transformations on a Signal are built on top of the following functions, implemented in CwlSignal.swift
extension SignalInterface {
	public func subscribe(context: Exec = .direct, _ handler: @escaping (Result<OutputValue, SignalEnd>) -> Void) -> SignalOutput<OutputValue> {
		return signal.subscribe(context: context, handler)
	}
	public func subscribeWhile(context: Exec = .direct, _ handler: @escaping (Result<OutputValue, SignalEnd>) -> Bool) {
		return signal.subscribeWhile(context: context, handler)
	}
	public func junction() -> SignalJunction<OutputValue> {
		return signal.junction()
	}
	public func transform<U>(context: Exec = .direct, _ processor: @escaping (Result<OutputValue, SignalEnd>) -> Signal<U>.Next) -> Signal<U> {
		return signal.transform(context: context, processor)
	}
	public func transform<S, U>(initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, Result<OutputValue, SignalEnd>) -> Signal<U>.Next) -> Signal<U> {
		return signal.transform(initialState: initialState, context: context, processor)
	}
	public func combine<U: SignalInterface, V>(_ second: U, context: Exec = .direct, _ processor: @escaping (EitherResult2<OutputValue, U.OutputValue>) -> Signal<V>.Next) -> Signal<V> {
		return signal.combine(second, context: context, processor)
	}
	public func combine<U: SignalInterface, V: SignalInterface, W>(_ second: U, _ third: V, context: Exec = .direct, _ processor: @escaping (EitherResult3<OutputValue, U.OutputValue, V.OutputValue>) -> Signal<W>.Next) -> Signal<W> {
		return signal.combine(second, third, context: context, processor)
	}
	public func combine<U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(_ second: U, _ third: V, _ fourth: W, context: Exec = .direct, _ processor: @escaping (EitherResult4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>) -> Signal<X>.Next) -> Signal<X> {
		return signal.combine(second, third, fourth, context: context, processor)
	}
	public func combine<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface, Y>(_ second: U, _ third: V, _ fourth: W, _ fifth: X, context: Exec = .direct, _ processor: @escaping (EitherResult5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>) -> Signal<Y>.Next) -> Signal<Y> {
		return signal.combine(second, third, fourth, fifth, context: context, processor)
	}
	public func combine<S, U: SignalInterface, V>(_ second: U, initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, EitherResult2<OutputValue, U.OutputValue>) -> Signal<V>.Next) -> Signal<V> {
		return signal.combine(second, initialState: initialState, context: context, processor)
	}
	public func combine<S, U: SignalInterface, V: SignalInterface, W>(_ second: U, _ third: V, initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, EitherResult3<OutputValue, U.OutputValue, V.OutputValue>) -> Signal<W>.Next) -> Signal<W> {
		return signal.combine(second, third, initialState: initialState, context: context, processor)
	}
	public func combine<S, U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(_ second: U, _ third: V, _ fourth: W, initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, EitherResult4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>) -> Signal<X>.Next) -> Signal<X> {
		return signal.combine(second, third, fourth, initialState: initialState, context: context, processor)
	}
	public func combine<S, U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface, Y>(_ second: U, _ third: V, _ fourth: W, _ fifth: X, initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, EitherResult5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>) -> Signal<Y>.Next) -> Signal<Y> {
		return signal.combine(second, third, fourth, fifth, initialState: initialState, context: context, processor)
	}
	public func continuous(initialValue: OutputValue) -> SignalMulti<OutputValue> {
		return signal.continuous(initialValue: initialValue)
	}
	public func continuous() -> SignalMulti<OutputValue> {
		return signal.continuous()
	}
	public func continuousWhileActive() -> SignalMulti<OutputValue> {
		return signal.continuousWhileActive()
	}
	public func playback() -> SignalMulti<OutputValue> {
		return signal.playback()
	}
	public func cacheUntilActive() -> Signal<OutputValue> {
		return signal.cacheUntilActive()
	}
	public func multicast() -> SignalMulti<OutputValue> {
		return signal.multicast()
	}
	public func customActivation(initialValues: Array<OutputValue> = [], context: Exec = .direct, _ updater: @escaping (_ cachedValues: inout Array<OutputValue>, _ cachedError: inout SignalEnd?, _ incoming: Result<OutputValue, SignalEnd>) -> Void) -> SignalMulti<OutputValue> {
		return signal.customActivation(initialValues: initialValues, context: context, updater)
	}
	public func reduce<State>(initialState: State, context: Exec = .direct, _ reducer: @escaping (_ state: State, _ message: OutputValue) throws -> State) -> SignalMulti<State> {
		return signal.reduce(initialState: initialState, context: context, reducer)
	}
	public func capture() -> SignalCapture<OutputValue> {
		return signal.capture()
	}
}

extension Signal {
	// Like `create` but also provides a trailing closure to transform the `Signal` normally returned from `create` and in its place, return the result of the transformation.
	//
	// - Parameter compose: a trailing closure which receices the `Signal` as a parameter and any result is returned as the second tuple parameter from this function
	// - Returns: a (`SignalInput`, U) tuple where `SignalInput` is the input to the signal graph and `U` is the return value from the `compose` function.
	// - Throws: rethrows any error from the closure
	public static func create<U>(compose: (Signal<OutputValue>) throws -> U) rethrows -> (input: SignalInput<OutputValue>, composed: U) {
		let (i, s) = Signal<OutputValue>.create()
		return (i, try compose(s))
	}
	
	/// A version of `generate` that retains the latest `input` so it doesn't automatically close the signal when the input falls out of scope. This enables a generator that never closes (lives until deactivation).
	///
	/// - Parameters:
	///   - context: the `activationChange` will be invoked in this context
	///   - activationChange: receives inputs on activation and nil on each deactivation
	/// - Returns: the constructed `Signal`
	public static func retainedGenerate(context: Exec = .direct, activationChange: @escaping (SignalInput<OutputValue>?) -> Void) -> Signal<OutputValue> {
		var latestInput: SignalInput<OutputValue>? = nil
		return .generate(context: context) { input in
			latestInput = input
			withExtendedLifetime(latestInput) {}
			activationChange(input)
		}
	}
	
	/// Change the default execution to an asynchronous context – typically the global concurrent queue.
	///
	/// This transformation exists as an optimization to multiple stages that must all run in the same queue (for thread-safety reasons) but also want to run asynchronously (to avoid blocking main or calling queues). e.g.:
	/// ```
	/// signal
	///    .map(context: myAsyncQueue) { v in work1(v) }
	///    .map(context: myAsyncQueue) { v in work2(v) }
	/// ```
	///
	/// The executation will not stay on `myAsyncQueue` between these stages... `Signal` must exit any non-reentrant context at the end of a processing stage as part of its thread safety rules. This means that execution through this pipeline takes the following path:
	///
	/// 1. asynchronously transfer to `myAsyncQueue` and run work1
	/// 2. asynchronously transfer to the dispatch global concurrent queue to leave `myAsyncQueue`
	/// 3. asynchronously transfer to `myAsyncQueue` and run work2
	/// 4. asynchronously transfer to the dispatch global concurrent queue to leave `myAsyncQueue`
	///
	/// This involves 4 asynchronous transfers, each of which has a latency of about 5 microseconds, leading to 20 microseconds minimum latency and a maximum throughput of 50 000 per second, when `work1` and `work2` are trivial.
	///
	/// Instead consider the following:
	/// ```
	/// signal
	///    .scheduleAsync()
	///    .map(context: mySyncQueue) { v in work1(v) }
	///    .map(context: mySyncQueue) { v in work2(v) }
	/// ```
	///
	/// Values travelling through this pipeline:
	/// 1. asynchronously transfer to the dispatch global concurrent queue
	/// 2. synchronously invoke on `mySyncQueue` and run work1
	/// 3. synchronously invoke on `mySyncQueue` and run work2
	///
	/// This pipeline offers the same thread safety – `work1` and `work2` are still invoked on the same serial queue – and is still asynchronous. But this arrangement involves 1 asynchronous transfer and 2 synchronous queue invocations, leading to around 7 microseconds minimum latency and a maximum throughput of nearly 150 000 per second, when `work1` and `work2` are trivial –– around 3 times faster (an advantage that increases for pipelines with more stages).
	///
	/// NOTE: there is no equivalent `scheduleMain` for transferring back to the main thread because the `Exec.main` context is reentrant (checks the current thread and directly invokes if `Thread.isMainThread` returns `true`) so `Signal` does not need to exit the context at the end of each pipeline stage. This function primarily exists to optimize DispatchQueues (e.g. `Exec.asyncQueue`) which are not reentrant.
	///
	/// - Parameter relativeTo: the global scheduling will be achieved by calling `relativeAsync` on this context.
	/// - Parameter qos: used as a parameter to `relativeAsync` to override the `QoSClass`, if desired. Default: `nil`
	/// - Returns: a signal which is transferred to an async context.
	public func scheduleAsync(relativeTo: Exec = .direct, qos: DispatchQoS.QoSClass? = nil) -> Signal<OutputValue> {
		return transform(context: relativeTo.relativeAsync(qos: qos), Signal<OutputValue>.Next.single)
	}
}

extension SignalInputInterface {
	/// A convenience version of `send` that wraps a value in `Result.success` before sending
	///
	/// - Parameter value: will be wrapped and sent
	/// - Returns: the return value from the underlying `send(result:)` function
	public func send(result: Signal<InputValue>.Result) {
		input.send(result: result)
	}
	
	/// A convenience version of `send` that wraps a value in `Result.success` before sending
	///
	/// - Parameter value: will be wrapped and sent
	/// - Returns: the return value from the underlying `send(result:)` function
	public func send(value: InputValue) {
		input.send(result: .success(value))
	}
	
	/// A convenience version of `send` that wraps a value in `Result.success` before sending
	///
	/// - Parameter value: will be wrapped and sent
	/// - Returns: the return value from the underlying `send(result:)` function
	public func send(_ values: InputValue...) {
		let i = self.input
		for v in values {
			i.send(result: .success(v))
		}
	}
	
	/// A convenience version of `send` that wraps a value in `Result.success` before sending
	///
	/// - Parameter value: will be wrapped and sent
	/// - Returns: the return value from the underlying `send(result:)` function
	public func send<S: Sequence>(sequence: S) where S.Iterator.Element == InputValue {
		let i = self.input
		for v in sequence {
			i.send(result: .success(v))
		}
	}
	
	/// A convenience version of `send` that wraps an error in `Result.failure` before sending
	///
	/// - Parameter error: will be wrapped and sent
	/// - Returns: the return value from the underlying `send(result:)` function
	public func send(error: Error) {
		input.send(result: .failure(.other(error)))
	}
	
	/// A convenience version of `send` that wraps an error in `Result.failure` before sending
	///
	/// - Parameter error: will be wrapped and sent
	/// - Returns: the return value from the underlying `send(result:)` function
	public func send(end: SignalEnd) {
		input.send(result: .failure(end))
	}
	
	/// Sends a `Result.failure(SignalEnd.complete)`
	///
	/// - Returns: the return value from the underlying `send(result:)` function
	public func complete() {
		input.send(result: .failure(.complete))
	}

	@available(*, deprecated, message: "Renamed `complete`")
	public func close() {
		complete()
	}
}

extension Signal.Next {
	public static func value(_ value: OutputValue) -> Signal<OutputValue>.Next {
		return .single(.success(value))
	}
	
	public static func value(_ value: OutputValue, end: SignalEnd) -> Signal<OutputValue>.Next {
		return .array([.success(value), .failure(end)])
	}
	
	public static func values(_ value: OutputValue...) -> Signal<OutputValue>.Next {
		return .array(value.map { Signal<OutputValue>.Result.success($0) })
	}
	
	public static func values(_ value: OutputValue..., end: SignalEnd) -> Signal<OutputValue>.Next {
		return .array(value.map { Signal<OutputValue>.Result.success($0) }.appending(.failure(end)))
	}
	
	public static func values<OutputValue, S: Sequence>(sequence: S) -> Signal<OutputValue>.Next where S.Element == OutputValue {
		return .array(sequence.map { Signal<OutputValue>.Result.success($0) })
	}
	
	public static func values<OutputValue, S: Sequence>(sequence: S, end: SignalEnd) -> Signal<OutputValue>.Next where S.Element == OutputValue {
		return .array(sequence.map { Signal<OutputValue>.Result.success($0) }.appending(.failure(end)))
	}
	
	public static func error(_ error: Error) -> Signal<OutputValue>.Next {
		return .single(.failure(.other(error)))
	}
	
	public static func end(_ end: SignalEnd) -> Signal<OutputValue>.Next {
		return .single(.failure(end))
	}
	
	public static func complete() -> Signal<OutputValue>.Next {
		return .single(.failure(.complete))
	}
}

/// Used by the Signal<OutputValue>.combine(second:context:handler:) method
public enum EitherValue2<U, V> {
	case value1(U)
	case value2(V)
}

/// Used by the Signal<OutputValue>.combine(second:third:context:handler:) method
public enum EitherValue3<U, V, W> {
	case value1(U)
	case value2(V)
	case value3(W)
}

/// Used by the Signal<OutputValue>.combine(second:third:fourth:context:handler:) method
public enum EitherValue4<U, V, W, X> {
	case value1(U)
	case value2(V)
	case value3(W)
	case value4(X)
}

/// Used by the Signal<OutputValue>.combine(second:third:fourth:fifth:context:handler:) method
public enum EitherValue5<U, V, W, X, Y> {
	case value1(U)
	case value2(V)
	case value3(W)
	case value4(X)
	case value5(Y)
}

extension SignalInterface {
	/// Removes any activation from the signal. Useful in cases when you only want *changes*, not the latest value.
	public func dropActivation() -> Signal<OutputValue> {
		let pair = Signal<OutputValue>.create()
		try! signal.capture().bind(to: pair.input)
		return pair.signal
	}
	
	/// Causes any activation to be deferred past activation time to the "normal" phase. This avoids the synchronous send rules normally used for activation signals an allows this initial signal to be asynchronously delivered.
	public func deferActivation() -> Signal<OutputValue> {
		let pair = Signal<OutputValue>.create()
		try! signal.capture().bind(to: pair.input, resend: true)
		return pair.signal
	}
	
	/// Appends a handler function that transforms the value emitted from this `Signal` into a new `Signal`.
	///
	/// - Parameters:
	///   - context: the `Exec` context used to invoke the `handler`
	///   - processor: the function invoked for each received `Result`
	/// - Returns: the created `Signal`
	public func transformValues<U>(context: Exec = .direct, _ processor: @escaping (OutputValue) -> Signal<U>.Next) -> Signal<U> {
		return transform(context: context) { r in
			switch r {
			case .success(let v): return processor(v)
			case .failure(let e): return .single(.failure(e))
			}
		}
	}
	
	/// Appends a handler function that transforms the value emitted from this `Signal` into a new `Signal`.
	///
	/// - Parameters:
	///   - initialState: the initial value for a state value associated with the handler. This value is retained and if the signal graph is deactivated, the state value is reset to this value.
	///   - context: the `Exec` context used to invoke the `handler`
	///   - processor: the function invoked for each received `Result`
	/// - Returns: the transformed output `Signal`
	public func transformValues<S, U>(initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, OutputValue) -> Signal<U>.Next) -> Signal<U> {
		return transform(initialState: initialState, context: context) { s, r in
			switch r {
			case .success(let v): return processor(&s, v)
			case .failure(let e): return .single(.failure(e))
			}
		}
	}

	/// Maps values from self or second to EitherValue2 and merges into a single stream.
	///
	/// - Parameter second: another signal
	/// - Returns: Signal<EitherValue2<OutputValue, U.OutputValue>>
	public func combineValues<U: SignalInterface>(_ second: U, closePropagation: SignalEndPropagation = .errors) -> Signal<EitherValue2<OutputValue, U.OutputValue>> {
		return signal.combine(second.signal, initialState: (false, false)) { (closed: inout (Bool, Bool), either: EitherResult2<OutputValue, U.OutputValue>) -> Signal<EitherValue2<OutputValue, U.OutputValue>>.Next in
			switch either {
			case .result1(.failure(let e)):
				if closed.1 || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.0 = true
				return .none
			case .result2(.failure(let e)):
				if closed.0 || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.1 = true
				return .none
			case .result1(.success(let v)): return .value(.value1(v))
			case .result2(.success(let v)): return .value(.value2(v))
			}
		}
	}

	public func combineValues<U: SignalInterface, V: SignalInterface>(_ second: U, _ third: V, closePropagation: SignalEndPropagation = .errors) -> Signal<EitherValue3<OutputValue, U.OutputValue, V.OutputValue>> {
		return signal.combine(second.signal, third.signal, initialState: (false, false, false)) { (closed: inout (Bool, Bool, Bool), either: EitherResult3<OutputValue, U.OutputValue, V.OutputValue>) -> Signal<EitherValue3<OutputValue, U.OutputValue, V.OutputValue>>.Next in
			switch either {
			case .result1(.failure(let e)):
				if (closed.1 && closed.2) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.0 = true
				return .end(e)
			case .result2(.failure(let e)):
				if (closed.0 && closed.2) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.1 = true
				return .end(e)
			case .result3(.failure(let e)):
				if (closed.0 && closed.1) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.2 = true
				return .end(e)
			case .result1(.success(let v)): return .value(.value1(v))
			case .result2(.success(let v)): return .value(.value2(v))
			case .result3(.success(let v)): return .value(.value3(v))
			}
		}
	}
	
	public func combineValues<U: SignalInterface, V: SignalInterface, W: SignalInterface>(_ second: U, _ third: V, fourth: W, closePropagation: SignalEndPropagation = .errors) -> Signal<EitherValue4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>> {
		return signal.combine(second.signal, third.signal, fourth.signal, initialState: (false, false, false, false)) { (closed: inout (Bool, Bool, Bool, Bool), either: EitherResult4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>) -> Signal<EitherValue4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>>.Next in
			switch either {
			case .result1(.failure(let e)):
				if (closed.1 && closed.2 && closed.3) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.0 = true
				return .end(e)
			case .result2(.failure(let e)):
				if (closed.0 && closed.2 && closed.3) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.1 = true
				return .end(e)
			case .result3(.failure(let e)):
				if (closed.0 && closed.1 && closed.3) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.2 = true
				return .end(e)
			case .result4(.failure(let e)):
				if (closed.0 && closed.1 && closed.2) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.3 = true
				return .end(e)
			case .result1(.success(let v)): return .value(.value1(v))
			case .result2(.success(let v)): return .value(.value2(v))
			case .result3(.success(let v)): return .value(.value3(v))
			case .result4(.success(let v)): return .value(.value4(v))
			}
		}
	}
	
	public func combineValues<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface>(_ second: U, _ third: V, _ fourth: W, _ fifth: X, closePropagation: SignalEndPropagation = .errors) -> Signal<EitherValue5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>> {
		return signal.combine(second.signal, third.signal, fourth.signal, fifth.signal, initialState: (false, false, false, false, false)) { (closed: inout (Bool, Bool, Bool, Bool, Bool), either: EitherResult5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>) -> Signal<EitherValue5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>>.Next in
			switch either {
			case .result1(.failure(let e)):
				if (closed.1 && closed.2 && closed.3 && closed.4) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.0 = true
				return .end(e)
			case .result2(.failure(let e)):
				if (closed.0 && closed.2 && closed.3 && closed.4) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.1 = true
				return .end(e)
			case .result3(.failure(let e)):
				if (closed.0 && closed.1 && closed.3 && closed.4) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.2 = true
				return .end(e)
			case .result4(.failure(let e)):
				if (closed.0 && closed.1 && closed.2 && closed.4) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.3 = true
				return .end(e)
			case .result5(.failure(let e)):
				if (closed.0 && closed.1 && closed.2 && closed.3) || closePropagation.shouldPropagateEnd(e) {
					return .end(e)
				}
				closed.4 = true
				return .end(e)
			case .result1(.success(let v)): return .value(.value1(v))
			case .result2(.success(let v)): return .value(.value2(v))
			case .result3(.success(let v)): return .value(.value3(v))
			case .result4(.success(let v)): return .value(.value4(v))
			case .result5(.success(let v)): return .value(.value5(v))
			}
		}
	}

	/// A version of `subscribe` that retains the `SignalOutput` internally, keeping the signal graph alive. The `SignalOutput` is cancelled and released when the signal closes.
	///
	/// NOTE: this subscriber deliberately creates a reference counted loop. If the signal is never closed, it will result in a memory leak. This function should be used only when `self` is guaranteed to close.
	///
	/// - Parameters:
	///   - context: the execution context where the `processor` will be invoked
	///   - handler: will be invoked with each value received and if returns `false`, the output will be cancelled and released
	public func subscribeUntilEnd(context: Exec = .direct, _ handler: @escaping (Result<OutputValue, SignalEnd>) -> Void) {
		return signal.subscribeWhile(context: context, { (result: Result<OutputValue, SignalEnd>) -> Bool in
			handler(result)
			return true
		})
	}
	
	/// A convenience version of `subscribe` that only invokes the `processor` on `Result.success`
	///
	/// - Parameters:
	///   - context: the execution context where the `processor` will be invoked
	///   - handler: will be invoked with each value received
	/// - Returns: the `SignalOutput` created by this function
	public func subscribeValues(context: Exec = .direct, _ handler: @escaping (OutputValue) -> Void) -> SignalOutput<OutputValue> {
		return signal.subscribe(context: context) { r in
			if case .success(let v) = r {
				handler(v)
			}
		}
	}
	
	/// A convenience version of `subscribeUntilEnd` that only invokes the `processor` on `Result.success`
	///
	/// NOTE: this subscriber deliberately creates a reference counted loop. If the signal is never closed, it will result in a memory leak. This function should be used only when `self` is guaranteed to close.
	///
	/// - Parameters:
	///   - context: the execution context where the `processor` will be invoked
	///   - handler: will be invoked with each value received and if returns `false`, the output will be cancelled and released
	public func subscribeValuesUntilEnd(context: Exec = .direct, _ handler: @escaping (OutputValue) -> Void) {
		signal.subscribeUntilEnd(context: context) { r in
			if case .success(let v) = r {
				handler(v)
			}
		}
	}
	
	/// A convenience version of `subscribeWhile` that only invokes the `processor` on `Result.success`
	///
	/// NOTE: this subscriber deliberately creates a reference counted loop. If the signal is never closed and the handler never returns false, it will result in a memory leak. This function should be used only when `self` is guaranteed to close or the handler `false` condition is guaranteed.
	///
	/// - Parameters:
	///   - context: the execution context where the `processor` will be invoked
	///   - handler: will be invoked with each value received and if returns `false`, the output will be cancelled and released
	public func subscribeValuesWhile(context: Exec = .direct, _ handler: @escaping (OutputValue) -> Bool) {
		signal.subscribeWhile(context: context) { r in
			if case .success(let v) = r {
				return handler(v)
			} else {
				return false
			}
		}
	}
	
	/// Returns a signal that drops an `initial` number of values from the start of the stream and emits the next value and every `count`-th value after that.
	///
	/// - Parameters:
	///   - count: number of values beteen emissions
	///   - initialSkip: number of values before the first emission
	/// - Returns: the strided signal
	public func stride(count: Int, initialSkip: Int = 0) -> Signal<OutputValue> {
		return signal.transform(initialState: count - initialSkip - 1) { (state: inout Int, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v) where state >= count - 1:
				state = 0
				return .value(v)
			case .success:
				state += 1
				return .none
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// A signal transform function that, instead of creating plain values and emitting them to a `SignalNext`, creates entire signals and adds them to a `SignalMergedInput`. The output of the merge set (which contains the merged output from all of the created signals) forms the signal returned from this function.
	///
	/// NOTE: this function is primarily used for implementing various Reactive X operators.
	///
	/// - Parameters:
	///   - closePropagation: whether signals added to the merge set will close the output
	///   - context: the context where the processor will run
	///   - processor: performs work with values from this `Signal` and the `SignalMergedInput` used for output
	/// - Returns: output of the merge set
	public func transformFlatten<U>(closePropagation: SignalEndPropagation = .none, context: Exec = .direct, _ processor: @escaping (OutputValue, SignalMergedInput<U>) throws -> ()) -> Signal<U> {
		return transformFlatten(initialState: (), closePropagation: closePropagation, context: context, { (state: inout (), value: OutputValue, mergedInput: SignalMergedInput<U>) in try processor(value, mergedInput) })
	}
	
	/// A signal transform function that, instead of creating plain values and emitting them to a `SignalNext`, creates entire signals and adds them to a `SignalMergedInput`. The output of the merge set (which contains the merged output from all of the created signals) forms the signal returned from this function.
	///
	/// NOTE: this function is primarily used for implementing various Reactive X operators.
	///
	/// - Parameters:
	///   - initialState: initial state for the state parameter passed into the processor
	///   - closePropagation: whether signals added to the merge set will close the output
	///   - context: the context where the processor will run
	///   - processor: performs work with values from this `Signal` and the `SignalMergedInput` used for output
	/// - Returns: output of the merge set
	public func transformFlatten<S, U>(initialState: S, closePropagation: SignalEndPropagation = .errors, context: Exec = .direct, _ processor: @escaping (inout S, OutputValue, SignalMergedInput<U>) throws -> ()) -> Signal<U> {
		let (mergedInput, result) = Signal<U>.createMergedInput()
		var end: SignalEnd? = nil
		let outerSignal = signal.transform(initialState: initialState, context: context) { (state: inout S, r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v):
				do {
					try processor(&state, v, mergedInput)
					return .none
				} catch {
					end = .other(error)
					return .error(error)
				}
			case .failure(let e):
				end = e
				return .end(e)
			}
		}
		
		// Keep the merge set alive at least as long as self
		mergedInput.add(outerSignal, closePropagation: closePropagation)
		
		return result.transform(initialState: nil) { [weak mergedInput] (onDelete: inout OnDelete?, r: Result<U, SignalEnd>) -> Signal<U>.Next in
			if onDelete == nil {
				onDelete = OnDelete {
					end = nil
				}
			}
			switch r {
			case .success(let v): return .value(v)
			case .failure(.cancelled):
				// If the `mergedInput` is `nil` at this point, that means that this `.cancelled` comes from the `mergedInput`, not one of its inputs. We'd prefer in that case to emit the `outerSignal`'s `closeError` rather than follow the `shouldPropagateEnd` logic.
				return .end(mergedInput == nil ? (end ?? .cancelled) : .cancelled)
			case .failure(let e):
				return .end(closePropagation.shouldPropagateEnd(e) ? e : (end ?? .cancelled))
			}
		}
	}

	/// A utility function, used by ReactiveX implementations, that generates "window" durations in single signal from the values in self and a "duration" function that returns duration signals for each value.
	///
	/// - Parameters:
	///   - closePropagation: passed through to the underlying `transformFlatten` call (unlikely to make much different in expected use cases of this function)
	///   - context: the context where `duration` will be invoked
	///   - duration: for each value emitted by `self`, emit a signal
	/// - Returns: a signal of two element tuples
	public func valueDurations<Interface: SignalInterface>(closePropagation: SignalEndPropagation = .none, context: Exec = .direct, _ duration: @escaping (OutputValue) -> Interface) -> Signal<(Int, OutputValue?)> {
		return valueDurations(initialState: (), closePropagation: closePropagation, context: context, { (state: inout (), value: OutputValue) -> Interface in duration(value) })
	}

	/// A utility function, used by ReactiveX implementations, that generates "window" durations in single signal from the values in self and a "duration" function that returns duration signals for each value.
	///
	/// - Parameters:
	///   - initialState: initial state for the state parameter passed into the processor
	///   - closePropagation: passed through to the underlying `transformFlatten` call (unlikely to make much different in expected use cases of this function)
	///   - context: the context where `duration` will be invoked
	///   - duration: for each value emitted by `self`, emit a signal
	/// - Returns: a signal of two element tuples
	public func valueDurations<Interface: SignalInterface, V>(initialState: V, closePropagation: SignalEndPropagation = .none, context: Exec = .direct, _ duration: @escaping (inout V, OutputValue) -> Interface) -> Signal<(Int, OutputValue?)> {
		return transformFlatten(initialState: (index: 0, userState: initialState), closePropagation: closePropagation, context: context) { (state: inout (index: Int, userState: V), v: OutputValue, mergedInput: SignalMergedInput<(Int, OutputValue?)>) in
			let count = state.index
			let innerSignal = duration(&state.userState, v).transform { (innerResult: Result<Interface.OutputValue, SignalEnd>) -> Signal<(Int, OutputValue?)>.Next in
				switch innerResult {
				case .success: return .none
				case .failure(let e): return .value((count, nil), end: e)
				}
			}
			let prefixedInnerSignal = Signal<(Int, OutputValue?)>.preclosed((count, Optional(v))).combine(innerSignal) { (r: EitherResult2<(Int, OutputValue?), (Int, OutputValue?)>) -> Signal<(Int, OutputValue?)>.Next in
				switch r {
				case .result1(.success(let v)): return .value(v)
				case .result1(.failure): return .none
				case .result2(.success(let v)): return .value(v)
				case .result2(.failure(let e)): return .end(e)
				}
			}

			mergedInput.add(prefixedInnerSignal, closePropagation: .none)
			state.index += 1
		}
	}
	
	/// A continuous signal which alternates between true and false values each time it receives a value.
	///
	/// - Parameter initialState: before receiving the first value
	/// - Returns: the alternating, continuous signal
	public func toggle(initialState: Bool = false) -> Signal<Bool> {
		return reduce(initialState: initialState) { (state: Bool, input: OutputValue) -> Bool in
			return !state
		}
	}

	/// A convenience transform to turn a signal of optional values into an signal of array values with one or zero elements.
	///
	/// - Returns: an array signal
	public func optionalToArray<U>() -> Signal<[U]> where OutputValue == Optional<U> {
		return signal.transform { (optional: Result<U?, SignalEnd>) -> Signal<[U]>.Next in
			switch optional {
			case .success(.some(let v)): return .value([v])
			case .success: return .value([])
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// A convenience transform to turn a signal of optional values into an signal of array values with one or zero elements.
	///
	/// - Returns: an array signal
	public func optional() -> Signal<OutputValue?> {
		return signal.transform { (optional: Result<OutputValue, SignalEnd>) -> Signal<OutputValue?>.Next in
			return .single(optional.map { $0 as OutputValue? })
		}
	}
	
	/// Joins this `Signal` to a destination `SignalInput`
	///
	/// WARNING: if you bind to a previously joined or otherwise inactive instance of the base `SignalInput` class, this function will have no effect. To get underlying errors, use `junction().bind(to: input)` instead.
	///
	/// - Parameters:
	///   - to: target `SignalMultiInput` to which this signal will be added
	public func bind<InputInterface>(to interface: InputInterface) where InputInterface: SignalInputInterface, InputInterface.InputValue == OutputValue {
		let input = interface.input
		if let multiInput = input as? SignalMultiInput<OutputValue> {
			multiInput.add(signal)
		} else {
			_ = try? signal.junction().bind(to: input)
		}
	}
	
	/// Joins this `Signal` to a destination `SignalMergedInput`
	///
	/// - Parameters:
	///   - to: target `SignalMultiInput` to which this signal will be added
	public func bind(to input: SignalMergedInput<OutputValue>, closePropagation: SignalEndPropagation, removeOnDeactivate: Bool = true) {
		input.add(signal, closePropagation: closePropagation, removeOnDeactivate: removeOnDeactivate)
	}
	
	/// Joins this `Signal` to a destination `SignalMultiInput` and returns a `Lifetime` that, when cancelled, will remove the `Signal` from the `SignalMultiInput` again.
	///
	/// - Parameters:
	///   - to: target `SignalMultiInput` to which this signal will be added
	/// - Returns: a `Lifetime` that will undo the bind if cancelled or released
	public func cancellableBind<InputInterface>(to interface: InputInterface) -> Lifetime where InputInterface: SignalInputInterface, InputInterface.InputValue == OutputValue {
		let input = interface.input
		if let multiInput = input as? SignalMultiInput<OutputValue> {
			let sig = signal
			multiInput.add(sig)
			return OnDelete { [weak multiInput, weak sig] in
				guard let mi = multiInput, let s = sig else { return }
				mi.remove(s)
			}
		} else {
			let j = signal.junction()
			_ = try? j.bind(to: input)
			return j
		}
	}
	
	/// Joins this `Signal` to a destination `SignalMultiInput` and returns a `Lifetime` that, when cancelled, will remove the `Signal` from the `SignalMultiInput` again.
	///
	/// - Parameters:
	///   - to: target `SignalMultiInput` to which this signal will be added
	/// - Returns: a `Lifetime` that will undo the bind if cancelled or released
	public func cancellableBind(to input: SignalMergedInput<OutputValue>, closePropagation: SignalEndPropagation, removeOnDeactivate: Bool = true) -> Lifetime {
		let sig = signal
		input.add(sig, closePropagation: closePropagation, removeOnDeactivate: removeOnDeactivate)
		return OnDelete { [weak input, weak sig] in
			guard let i = input, let s = sig else { return }
			i.remove(s)
		}
	}

	/// - Returns: a signal where value in the sequence is accompanied by its zero-indexed position in the sequence
	public func enumerated() -> Signal<(offset: Int, element: OutputValue)> {
		return transform(initialState: -1) { index, result in
			index += 1
			return .single(result.map { (offset: index, element: $0) })
		}
	}
	
	/// Given an array of source Signals, returns a single, merged Signal where each value is a tuple of the index in the array and the element from the corresponding source signal. 
	///
	/// - Parameter sequence: an sequence of SignalInterfaces
	/// - Returns: a merged signal of (offset, element) tuples
	public static func indexed<S: Sequence>(_ sequence: S) -> Signal<(offset: Int, element: OutputValue)> where S.Element: SignalInterface, OutputValue == S.Element.OutputValue {
		return Signal<(offset: Int, element: OutputValue)>.merge(sequence: sequence.enumerated().map { offset, s in s.map { (offset: offset, element: $0) } })
	}
}

/// This class is used for disconnecting and reconnecting a preceeding signal subgraph from the succeeding signal subgraph. This is useful in cases where you have a generating signal that will automatically pause itself when disconnected (like `Signal.interval`) and you want to disconnect it and reconnect to take advantage of that pause and restart functionality.
/// Internally, this class is a wrapper around a `SignalJunction` (which disconnects the succeeding graph) and a `Signal` (which is the head of the succeeding graph) and 
public struct SignalReconnector<OutputValue>: Lifetime {
	let queue = PThreadMutex()
	var disconnectedInput: SignalInput<OutputValue>?
	let junction: SignalJunction<OutputValue>
	
	public mutating func reconnect() {
		let input = queue.sync { () -> SignalInput<OutputValue>? in
			let di = disconnectedInput
			disconnectedInput = nil
			return di
		}
		if let i = input {
			_ = try? junction.bind(to: i)
		}
	}
	
	public mutating func cancel() {
		junction.cancel()
		queue.sync {
			disconnectedInput?.cancel()
			disconnectedInput = nil
		}
	}
	
	public mutating func disconnect() {
		if let i = junction.disconnect() {
			queue.sync {
				disconnectedInput = i
			}
		}
	}
	
	public init(preceeding: Signal<OutputValue>, succeeding: SignalInput<OutputValue>, initiallyConnected: Bool = true) {
		disconnectedInput = succeeding
		junction = preceeding.junction()
		if initiallyConnected {
			reconnect()
		}
	}
}

extension SignalInterface {
	/// Create a `SignalReconnector` and a downstream `Signal`. The `SignalReconnector` is used for disconnecting and reconnecting the downstream signal from `self`. This is useful in cases where `self` is a generating signal that automatically pauses itself when disconnected from all outputs (like `Signal.interval`) and you want to take advantage of that pause and restart functionality.
	///
	/// - Parameter initiallyConnected: should the downstream signal be connected when this function returns
	/// - Returns: a tuple of `SignalReconnector` and `Signal`. The reconnector disconnects `self` (upstream) from the `Signal` in the tuple (downstream). 
	public func reconnector(initiallyConnected: Bool = true) -> (SignalReconnector<OutputValue>, Signal<OutputValue>) {
		let (i, s) = Signal<OutputValue>.create()
		return (SignalReconnector<OutputValue>(preceeding: signal, succeeding: i, initiallyConnected: initiallyConnected), s)
	}
}

/// This wrapper around `SignalOutput` saves the last received value from the signal so that it can be 'polled' (read synchronously from an arbitrary execution context). This class ensures thread-safety on the read operation.
///
/// The typical use-case for this type of class is in the implementation of delegate methods and similar callback functions that must synchronously return a value.
///
/// Note that there is a semantic difference between this class which is intended to be left active for some time and polled periodically and `SignalCapture` which captures the *activation* value (leaving it running for a duration is pointless). For that reason, the standalone `peek()` function actually uses `SignalCapture` rather than this class (`SignalCapture` is more consistent in the presence of multi-threaded updates since there is no possibility of asychronous updates between creation and reading).
///
/// However, `SignalCapture` can only read activation values (not regular values). Additionally, `peek()` will be less efficient than this class if multiple reads are required since the `SignalCapture` is created and thrown away each time.
///
/// **WARNING**: this class should be avoided where possible since it removes the "reactive" part of reactive programming (changes in the polled value must be detected through other means, usually another subscriber to the underlying `Signal`).
///
public final class SignalLatest<OutputValue>: Lifetime {
	var output: SignalOutput<OutputValue>? = nil
	var latest: Result<OutputValue, SignalEnd>? = nil
	let mutex = Exec.syncQueue()
	
	public init(signal: Signal<OutputValue>) {
		output = signal.subscribe(context: mutex) { [weak self] r in
			self?.latest = r
		}
	}
	
	public var latestResult: Result<OutputValue, SignalEnd>? {
		return mutex.invokeSync { latest }
	}
	
	public var latestValue: OutputValue? {
		return mutex.invokeSync { latest?.value }
	}
	
	public func cancel() {
		output?.cancel()
	}
}

/// A SignalCapture subscribes to a signal and records any synchronously emitted "activation" values.
/// If there is no value to return or the value can't be emitted synchronously, this error may be returned.
public struct SignalCaptureFailedToEmit: Error {}

extension SignalInterface {
	/// Appends a `SignalLatest` listener to the value emitted from this `Signal`. `SignalLatest` adds an output to the signal and remembers the latest result emitted. This latest result can be accessed in a thread-safe way, using `latestValue` or `latestResult`.
	public func cacheLatest() -> SignalLatest<OutputValue> {
		return SignalLatest(signal: signal)
	}
	
	/// Internally creates a `SignalCapture` which reads the latest activation value and is immediately discarded.
	///
	/// NOTE: if you're not specifically interested in activation values or you're performing multiple times, the
	/// performance of `cacheLatest` is better.
	///
	/// - Returns: the latest captured value, if any
	/// - Throws: if no value is emitted but a `SignalEnd` is emitted, then the `SignalEnd` will be thrown. If no value or end is emitted, a `SignalCapture.FailedToEmit` error will be thrown.
	public func peek() throws -> OutputValue {
		return try signal.capture().latestValue()
	}
}

extension SignalCapture: SignalInterface {
	public var signal: Signal<OutputValue> { return resume() }
}

extension Result where Failure == SignalEnd {
	/// A minor convenience so that parameters requesting a `Result` can be passed `.signalComplete`
	public static var signalComplete: Result<Success, SignalEnd> { return Result<Success, SignalEnd>.failure(.complete) }
	
	/// A convenience extension on `Result` to test if it wraps a `SignalComplete`
	public var isComplete: Bool {
		switch self {
		case .failure(.complete): return true
		default: return false
		}
	}
}
