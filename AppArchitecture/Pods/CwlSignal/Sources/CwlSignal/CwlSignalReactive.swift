//
//  CwlSignalReactive.swift
//  CwlSignal
//
//  Created by Matt Gallagher on 2016/09/08.
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

#if swift(>=4)
#else
	public typealias Numeric = IntegerArithmetic & ExpressibleByIntegerLiteral
	public typealias BinaryInteger = IntegerArithmetic & ExpressibleByIntegerLiteral
#endif

/// Errors used by the Reactive extensions on Signal.
/// - timeout: used to close the stream when the Signal.timeout function reaches its limit.
public enum SignalReactiveError: Error {
	case timeout
}

/// For `mapActivation`, in the event of multiple activation values, you must device which of the activation values to process using the activation closure.
///
/// - all: process all activation values using the `activation` closure and all remaining values using the `remainder` closure (default)
/// - first: process the first activation value using the `activation` closure and process any remaining activation values using the `remainder` closure 
/// - last: process the last activation value using the `activation` closure, *discarding* all preceeding activation values, then process all subsequent values using the `remainder` closure
public enum SignalActivationSelection {
	case all
	case first
	case last
}

extension SignalInterface {
	/// - Note: the [Reactive X operator "Create"](http://reactivex.io/documentation/operators/create.html) is considered unnecessary, given the `CwlSignal.Signal.generate` and `CwlSignal.Signal.create` methods.
	
	/// - Note: the [Reactive X operator "Defer"](http://reactivex.io/documentation/operators/defer.html) is considered not applicable, given the different semantics of "activation" with `CwlSignal.Signal`. If `Defer`-like behavior is desired, either a method that constructs and returns a new `Signal` graph should be used (if a truly distinct graph is desired) or `CwlSignal.Signal.generate` should be used (if wait-until-activated behavior is desired).
}

extension Signal {
	/// Implementation of [Reactive X operator "From"](http://reactivex.io/documentation/operators/from.html) in the context of the Swift `Sequence`
	///
	/// See also: `preclosed(:)`, which is a shareable activation sequence
	/// See also: `just(:)`, which offers the same functionality but accepts a variable argument list instead of a sequence
	///
	/// NOTE: it is possible to specify a `nil` error to have the signal remain open at the end of the sequence.
	///
	/// - parameter values: A Swift `Sequence` that generates the signal values.
	/// - parameter end: The error with which to close the sequence. Can be `nil` to leave the sequence open (default: `SignalEnd.complete`)
	/// - parameter context: the `Exec` where the `SequenceType` will be enumerated (default: .direct).
	/// - returns: a signal that emits `values` and then closes
	public static func from<S: Sequence>(_ sequence: S, end: SignalEnd? = .complete, context: Exec = .direct) -> Signal<OutputValue> where S.Iterator.Element == OutputValue {
		if let e = end {
			return generate(context: context) { input in
				guard let i = input else { return }
				for v in sequence {
					if let _ = i.send(result: .success(v)) {
						break
					}
				}
				i.send(end: e)
			}
		} else {
			return retainedGenerate(context: context) { input in
				guard let i = input else { return }
				for v in sequence {
					if let _ = i.send(result: .success(v)) {
						break
					}
				}
			}
		}
	}

	/// Implementation of [Reactive X operator "Never"](http://reactivex.io/documentation/operators/empty-never-throw.html)
	///
	/// Implemented as `.from([], end: nil)`
	///
	/// - returns: a non-sending, non-closing signal of the desired type
	public static func never() -> Signal<OutputValue> {
		return .from([], end: nil)
	}
	
	/// - Implementation of [Reactive X operator "Just"](http://reactivex.io/documentation/operators/just.html)
	///
	/// See also: `from(:)`, which sends a sequence of values (optionally on a specific context)
	/// See also: `preclosed(:)`, which is a shareable activation sequence
	///
	/// - Parameters:
	///   - value: the value to send
	///   - end: if non-nil, sent after value to close the stream 
	/// - Returns: a signal that will emit `value` and (optionally) close
	public static func just(_ values: OutputValue..., end: SignalEnd? = .complete) -> Signal<OutputValue> {
		return .from(values, end: end)
	}

	/// - Implementation of [Reactive X operator "Throw"](http://reactivex.io/documentation/operators/empty-never-throw.html)
	///
	/// See also: `from(:)`, which sends a sequence of values (optionally on a specific context)
	/// See also: `preclosed(:)`, which is a shareable activation sequence
	///
	/// - Parameters:
	///   - value: the value to send
	///   - end: if non-nil, sent after value to close the stream 
	/// - Returns: a signal that will emit `value` and (optionally) close
	public static func error(_ error: Error) -> Signal<OutputValue> {
		return Signal<OutputValue>.from([], end: .other(error))
	}

	/// - Implementation of [Reactive X operator "Empty"](http://reactivex.io/documentation/operators/empty-never-throw.html)
	///
	/// See also: `from(:)`, which sends a sequence of values (optionally on a specific context)
	///
	/// - Returns: a signal that will emit no values and then close
	public static func empty() -> Signal<OutputValue> {
		return Signal<OutputValue>.from([])
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "To"](http://reactivex.io/documentation/operators/to.html) in the context of the Swift `Sequence`
	///
	/// WARNING: Because it blocks the receiving thread, and because it undermines the principle of *reactive* programming, this function should only be used in specific circumstances.
	///
	/// `SignalSequence` subscribes to `self` and blocks. This means that if any earlier signals in the graph force processing on the same context where `SignalSequence` is iterated, a deadlock may occur between the iteration and the signal processing.
	/// This function is safe only when you can guarantee all parts of the signal graph are independent of the blocking context.
	public func toSequence() -> SignalSequence<OutputValue> {
		return SignalSequence<OutputValue>(signal)
	}
}

/// Represents a Signal<OutputValue> converted to a synchronously iterated sequence. Values can be obtained using typical SequenceType actions. The error that ends the sequence is available through the `error` property.
public class SignalSequence<OutputValue>: Sequence, IteratorProtocol {
	typealias GeneratorType = SignalSequence<OutputValue>
	typealias ElementType = OutputValue
	
	let semaphore = DispatchSemaphore(value: 0)
	let context = Exec.syncQueue()
	var output: SignalOutput<OutputValue>? = nil
	
	var queued: Array<OutputValue> = []
	
	/// Error type property is `nil` before the end of the signal is reached and contains the error used to close the signal in other cases
	public var end: SignalEnd?
	
	// Only intended to be constructed by `Signal.toSequence`
	//
	// - Parameter signal: the signal whose values will be iterated by this sequence
	init(_ signal: Signal<OutputValue>) {
		output = signal.subscribe(context: context) { [weak self] (r: Result<OutputValue, SignalEnd>) in
			guard let s = self else { return }
			switch r {
			case .success(let v):
				s.queued.append(v)
				s.semaphore.signal()
			case .failure(let e):
				s.end = e
				s.semaphore.signal()
			}
		}
	}
	
	/// Stops listening to the signal and set the error value to SignalComplete.cancelled
	public func cancel() {
		context.invokeSync {
			self.end = .cancelled
			self.output?.cancel()
			self.semaphore.signal()
		}
	}
	
	/// Implementation of GeneratorType method.
	public func next() -> OutputValue? {
		_ = semaphore.wait(timeout: DispatchTime.distantFuture)
		return context.invokeSync { [weak self] () -> OutputValue? in
			guard let s = self else { return nil }
			if !s.queued.isEmpty {
				return s.queued.removeFirst()
			} else {
				// Signal the sempahore so that `nil` can be fetched again.
				s.semaphore.signal()
				return nil
			}
		}
	}
	
	deinit {
		if end == nil {
			semaphore.signal()
		}
	}
}

extension SignalInterface where OutputValue == Int {

	/// Implementation of [Reactive X operator "Interval"](http://reactivex.io/documentation/operators/interval.html)
	///
	/// - Parameters:
	///   - interval: duration between values
	///   - initialInterval: duration until first value
	///   - context: execution context where the timer will run
	/// - Returns: the interval signal
	public static func interval(_ interval: DispatchTimeInterval = .seconds(1), initial initialInterval: DispatchTimeInterval? = nil, context: Exec = .global) -> Signal<Int> {
		// We need to protect the `count` variable and make sure that out-of-date timers don't update it so we use a `serialized` context for the `generate` and the timers, since the combination of the two will ensure that these requirements are met.
		let serialContext = context.serialized()
		var timer: Lifetime? = nil
		var count = 0
		
		return Signal<Int>.generate(context: serialContext) { input in
			guard let i = input else {
				timer?.cancel()
				count = 0
				return
			}
			
			let repeater = {
				timer = serialContext.periodicTimer(interval: interval) {
					i.send(value: count)
					count += 1
				}
			}
			
			if let initial = initialInterval {
				if initial == .seconds(0) {
					i.send(value: count)
					count += 1
					repeater()
				} else {
					timer = serialContext.singleTimer(interval: initial) {
						i.send(value: count)
						count += 1
						repeater()
					}
				}
			} else {
				repeater()
			}
		}
	}
}

extension SignalInterface {
	/// - Note: the [Reactive X operator `Range`](http://reactivex.io/documentation/operators/range.html) is considered unnecessary, given that ranges are already handled by `from(:)`.
}

extension Signal {
	/// Implementation of [Reactive X operator "Repeat"](http://reactivex.io/documentation/operators/repeat.html) for a Swift `CollectionType`
	///
	/// - Parameters:
	///   - values: A Swift `CollectionType` that generates the signal values.
	///   - count: the number of times that `values` will be repeated.
	///   - context: the `Exec` where the `SequenceType` will be enumerated.
	/// - Returns: a signal that emits `values` a `count` number of times and then closes
	public static func repeatCollection<C: Collection>(_ values: C, count: Int, context: Exec = .direct) -> Signal<OutputValue> where C.Iterator.Element == OutputValue {
		return generate(context: context) { input in
			guard let i = input else { return }
			for _ in 0..<count {
				for v in values {
					if i.send(result: .success(v)) != nil {
						break
					}
				}
			}
			i.complete()
		}
	}
	
	/// Implementation of [Reactive X operator "Start"](http://reactivex.io/documentation/operators/start.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `f` will be evaluated (default: .direct).
	///   - f: a function that is run to generate the value.
	/// - Returns: a signal that emits a single value emitted from a function
	public static func start(context: Exec = .direct, f: @escaping () -> OutputValue) -> Signal<OutputValue> {
		return Signal.generate(context: context) { input in
			guard let i = input else { return }
			i.send(value: f())
			i.complete()
		}
	}
	
	/// Implementation of [Reactive X operator "Timer"](http://reactivex.io/documentation/operators/timer.html)
	///
	/// - Parameters:
	///   - interval: the time until the value is sent.
	///   - value: the value that will be sent before closing the signal (if `nil` then the signal will simply be closed at the end of the timer)
	///   - context: execution context where the timer will be run
	/// - Returns: the timer signal
	public static func timer(interval: DispatchTimeInterval, value: OutputValue? = nil, context: Exec = .global) -> Signal<OutputValue> {
		var timer: Lifetime? = nil
		return Signal<OutputValue>.generate(context: context) { input in
			if let i = input {
				timer = context.singleTimer(interval: interval) {
					if let v = value {
						i.send(value: v)
					}
					i.complete()
				}
			} else {
				timer?.cancel()
			}
		}
	}
}
	
extension SignalInterface {
	/// A shared function for emitting a boundary signal usable by the timed, non-overlapping buffer/window functions buffer(timeshift:count:continuous:behavior:) or window(timeshift:count:continuous:behavior:)
	///
	/// - Parameters:
	///   - interval: maximum duration between boundaries
	///   - count: maximum number of signal values between boundaries
	///   - continuous: timer is paused immediately after a boundary until the next value is received
	///   - context: execution context where the timer will be run
	/// - Returns: the boundary signal
	private func timedCountedBoundary(interval: DispatchTimeInterval, count: Int, continuous: Bool, context: Exec) -> Signal<Void> {
		// An interval signal
		let intSig = Signal.interval(interval, context: context)
		
		if count == Int.max {
			// If number of values per boundary is infinite, then all we need is the timer signal
			return intSig.map { v in () }
		}
		
		// The interval signal may need to be disconnectable so create a junction
		let intervalJunction = intSig.junction()
		let (initialInput, sig) = Signal<Int>.create()
		
		// Continuous signals don't really need the junction. Just connect it immediately and ignore it.
		if continuous {
			// Both `intervalJunction` and `initialInput` are newly created so this can't be an error
			try! intervalJunction.bind(to: initialInput)
		}
		
		return combine(sig, initialState: (0, nil)) { (state: inout (count: Int, timerInput: SignalInput<Int>?), cr: EitherResult2<OutputValue, Int>) -> Signal<Void>.Next in
			var send = false
			switch cr {
			case .result1(.success):
				// Count the values received per window
				state.count += 1
				
				// If we hit `count` values, trigger the boundary signal
				if state.count == count {
					send = true
				} else if !continuous, let i = state.timerInput {
					// If we're not continuous, make sure the timer is connected
					do {
						try intervalJunction.bind(to: i)
					} catch {
						return .end(.other(error))
					}
				}
			case .result1(.failure(let e)):
				// If there's an error on the `self` signal, forward it on.
				return .end(e)
			case .result2(.success):
				// When the timer fires, trigger the boundary signal
				send = true
			case .result2(.failure(let e)):
				// If there's a timer error, close
				return .end(e)
			}
			
			if send {
				// Reset the count and – if not continuous – disconnect the timer until we receive a signal from `self`
				state.count = 0
				if !continuous {
					state.timerInput = intervalJunction.disconnect()
				}
				
				// Send the boundary signal
				return .value(())
			} else {
				return .none
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Buffer"](http://reactivex.io/documentation/operators/buffer.html) for non-overlapping/no-gap buffers.
	///
	/// - Parameter boundaries: when this `Signal` sends a value, the buffer is emitted and cleared
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `boundaries`
	public func buffer<Interface: SignalInterface>(boundaries: Interface) -> Signal<[OutputValue]> {
		return combine(boundaries, initialState: [OutputValue]()) { (buffer: inout [OutputValue], cr: EitherResult2<OutputValue, Interface.OutputValue>) -> Signal<[OutputValue]>.Next in
			switch cr {
			case .result1(.success(let v)):
				buffer.append(v)
				return .none
			case .result1(.failure(let e)):
				let b = buffer
				buffer.removeAll()
				return .value(b, end: e)
			case .result2(.success):
				let b = buffer
				buffer.removeAll()
				return .value(b)
			case .result2(.failure(let e)):
				let b = buffer
				buffer.removeAll()
				return .value(b, end: e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Buffer"](http://reactivex.io/documentation/operators/buffer.html) for buffers with overlap or gaps between.
	///
	/// - Parameter windows: a "windows" signal (one that describes a series of times and durations). Each value `Signal` in the stream starts a new buffer and when the value `Signal` closes, the buffer is emitted.
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `windows`
	public func buffer<Interface: SignalInterface>(windows: Interface) -> Signal<[OutputValue]> where Interface.OutputValue: SignalInterface {
		return combine(windows.valueDurations { s in s }, initialState: [Int: [OutputValue]]()) { (buffers: inout [Int: [OutputValue]], cr: EitherResult2<OutputValue, (Int, Interface.OutputValue?)>) -> Signal<[OutputValue]>.Next in
			switch cr {
			case .result1(.success(let v)):
				for index in buffers.keys {
					buffers[index]?.append(v)
				}
				return .none
			case .result1(.failure(let e)):
				let values = buffers.map { $0.1 }
				buffers.removeAll()
				return .values(sequence: values, end: e)
			case .result2(.success(let index, .some)):
				buffers[index] = []
				return .none
			case .result2(.success(let index, .none)):
				if let b = buffers[index] {
					buffers.removeValue(forKey: index)
					return .value(b)
				}
				return .none
			case .result2(.failure(let e)):
				let values = buffers.map { $0.1 }
				buffers.removeAll()
				return .values(sequence: values, end: e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Buffer"](http://reactivex.io/documentation/operators/buffer.html) for buffers of fixed length and a fixed number of values separating starts.
	///
	/// - Parameters:
	///   - count: the number of separate values to accumulate before emitting an array of values
	///   - skip: the stride between the start of each new buffer (can be smaller than `count`, resulting in overlapping buffers)
	/// - Returns: a signal where the values are arrays of length `count` of values from `self`, with start values separated by `skip`
	public func buffer(count: UInt, skip: UInt) -> Signal<[OutputValue]> {
		if count == 0 {
			return Signal<[OutputValue]>.preclosed()
		}
		
		let multi = multicast()
		
		// Create the two listeners to the "multi" signal carefully so that the window signal is *first* (so it reaches the buffer before the value signal)
		let windowSignal = multi.stride(count: Int(skip)).map { _ in
			// `count - 1` is the index of the count-th element but since `valuesSignal` will resolve before this, we need to fire 1 element sooner, hence `count - 2`
			multi.elementAt(count - 2).ignoreElements(outputType: OutputValue.self)
		}
		
		return multi.buffer(windows: windowSignal)
	}
	
	/// Implementation of [Reactive X operator "Buffer"](http://reactivex.io/documentation/operators/buffer.html) for non-overlapping, periodic buffer start times and possibly limited buffer sizes.
	///
	/// - Parameters:
	///   - interval: number of seconds between the start of each buffer
	///   - count: the number of separate values to accumulate before emitting an array of values
	///   - continuous: if `true` (default), the `timeshift` periodic timer runs continuously (empty buffers may be emitted if a timeshift elapses without any source signals). If `false`, the periodic timer does start until the first value is received from the source and the periodic timer is paused when a buffer is emitted.
	///   - context: context where the timer will be run
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `windows
	public func buffer(interval: DispatchTimeInterval, count: Int = Int.max, continuous: Bool = true, context: Exec = .direct) -> Signal<[OutputValue]> {
		let multi = multicast()
		
		// Create the two listeners to the "multi" signal carefully so that the raw signal is *first* (so it reaches the buffer before the boundary signal)
		let valuesSignal = multi.map { v in v }
		let boundarySignal = multi.timedCountedBoundary(interval: interval, count: count, continuous: continuous, context: context)
		
		return valuesSignal.buffer(boundaries: boundarySignal)
	}
	
	/// Implementation of [Reactive X operator "Buffer"](http://reactivex.io/documentation/operators/buffer.html) for non-overlapping buffers of fixed length.
	///
	/// - Note: this is just a convenience wrapper around `buffer(count:skip:)` where `skip` equals `count`.
	///
	/// - Parameter count: the number of separate values to accumulate before emitting an array of values
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `count`
	public func buffer(count: UInt) -> Signal<[OutputValue]> {
		return buffer(count: count, skip: count)
	}
	
	/// Implementation of [Reactive X operator "Buffer"](http://reactivex.io/documentation/operators/buffer.html) for periodic buffer start times and fixed duration buffers.
	///
	/// - Note: this is just a convenience wrapper around `buffer(windows:behaviors)` where the `windows` signal contains `timerSignal` signals contained in a `Signal.interval` signal.
	///
	/// - Parameters:
	///   - interval: the duration of each buffer, in seconds.
	///   - timeshift: the number of seconds between the start of each buffer (if smaller than `interval`, buffers will overlap).
	///   - context: context where the timer will be run
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `windows`
	public func buffer(interval: DispatchTimeInterval, timeshift: DispatchTimeInterval, context: Exec = .direct) -> Signal<[OutputValue]> {
		return buffer(windows: Signal.interval(timeshift, initial: .seconds(0), context: context).map { v in Signal<Void>.timer(interval: interval, context: context) })
	}
	
	/// Implementation of map and filter. Essentially a flatMap but instead of flattening over child `Signal`s like the standard Reactive implementation, this flattens over child `Optional`s.
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func compact<U>() -> Signal<U> where OutputValue == Optional<U> {
		return transform() { (r: Result<Optional<U>, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(.some(let v)): return .value(v)
			case .success: return .none
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of map and filter. Essentially a flatMap but instead of flattening over child `Signal`s like the standard Reactive implementation, this flattens over child `Optional`s.
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func compactMap<U>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> U?) -> Signal<U> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v):
				do {
					if let u = try processor(v) {
						return .value(u)
					}
					return .none
				} catch {
					return .end(.other(error))
				}
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of map and filter. Essentially a flatMap but instead of flattening over child `Signal`s like the standard Reactive implementation, this flattens over child `Optional`s.
	///
	/// - Parameters:
	///   - initialState: an initial value for a state parameter that will be passed to the processor on each iteration.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func compactMap<S, U>(initialState: S, context: Exec = .direct, _ processor: @escaping (inout S, OutputValue) throws -> U?) -> Signal<U> {
		return transform(initialState: initialState, context: context) { (s: inout S, r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v):
				do {
					if let u = try processor(&s, v) {
						return .value(u)
					}
					return .none
				} catch {
					return .end(.other(error))
				}
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Equivalent to a compactMap over the activation values in the sequence but passthrough for the other values.
	///
	/// - Parameters:
	///   - select: chooses which end (first or last) 
	///   - context: the `Exec` where `activation` will be evaluated (default: .direct).
	///   - activation: processing closure for activation values
	/// - Returns: a `Signal` where all the activation values have been transformed by `activation` and all other values have been transformed by `remained`. Any error is emitted in the output without change.
	public func compactMapActivation<U>(select: SignalActivationSelection, context: Exec = .direct, activation: @escaping (OutputValue) throws -> U?, remainder: @escaping (OutputValue) throws -> U?) -> Signal<U> {
		var capture: SignalCapture<OutputValue>? = nil
		return Signal<U>.generate { input in
			guard let input = input else { return }
			
			let c: SignalCapture<OutputValue>
			if let cap = capture {
				// Subsequent runs, disconnect the old capture to restart it
				_ = cap.disconnect()
				c = cap
			} else {
				// First run, start the capture.
				c = self.capture()
				capture = c
			}
			
			// Subsequent values will be compactMapped normally
			var subsequent = c.resume().compactMap(context: context, remainder)
			
			let values = c.values
			guard !values.isEmpty else {
				subsequent.bind(to: input)
				return
			}
			
			var initial: [U]? = nil
			do {
				// Process the captured values
				switch select {
				case .all: initial = try context.invokeSync { try values.compactMap(activation) }
				case .first:
					initial = [U]()
					try context.invokeSync {
						if let v = values.first, let a = try activation(v) {
							initial!.append(a)
						}
						for v in values.dropFirst() {
							if let r = try remainder(v) {
								initial!.append(r)
							}
						}
					}
				case .last:
					initial = try values.last.flatMap { v in try context.invokeSync { try activation(v).map { [$0] } } }
				}
				
				// If we have any initial values, precache them for immediate sending
				if let i = initial, !i.isEmpty {
					subsequent = subsequent.cacheUntilActive(precached: i)
				}
			} catch {
				subsequent = Signal<U>.preclosed(sequence: initial ?? [], end: SignalEnd.other(error))
			}
		
			subsequent.bind(to: input)
		}		
	}

	public func compactMapLatestActivation(context: Exec = .direct, activation: @escaping (OutputValue) throws -> OutputValue?) -> Signal<OutputValue> {
		var capture: SignalCapture<OutputValue>? = nil
		return Signal<OutputValue>.generate { input in
			guard let input = input else { return }
			
			let c: SignalCapture<OutputValue>
			if let cap = capture {
				// Subsequent runs, disconnect the old capture to restart it
				_ = cap.disconnect()
				c = cap
			} else {
				// First run, start the capture.
				c = self.capture()
				capture = c
			}
			
			let values = c.values
			guard !values.isEmpty else {
				c.resume().bind(to: input)
				return
			}
			
			do {
				let initial = try values.last.flatMap { v in try context.invokeSync { try activation(v).map { [$0] } } }
				if let i = initial, !i.isEmpty {
					return c.resume().cacheUntilActive(precached: i).bind(to: input)
				} else {
					return c.resume().bind(to: input)
				}
			} catch {
				Signal<OutputValue>.preclosed(end: SignalEnd.other(error)).bind(to: input)
			}
		}		
	}
	
	/// Implementation of [Reactive X operator "FlatMap"](http://reactivex.io/documentation/operators/flatmap.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func flatten<Interface: SignalInterface>() -> Signal<Interface.OutputValue> where OutputValue == Interface {
		return transformFlatten(closePropagation: .errors) { (v: OutputValue, mergedInput: SignalMergedInput<Interface.OutputValue>) in
			mergedInput.add(v, closePropagation: .errors, removeOnDeactivate: true)
		}
	}
	
	/// Implementation of [Reactive X operator "FlatMap"](http://reactivex.io/documentation/operators/flatmap.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func flatMap<Interface: SignalInterface>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> Interface) -> Signal<Interface.OutputValue> {
		return transformFlatten(closePropagation: .errors, context: context) { (v: OutputValue, mergedInput: SignalMergedInput<Interface.OutputValue>) in
			mergedInput.add(try processor(v), closePropagation: .errors, removeOnDeactivate: true)
		}
	}
	
	/// Implementation of [Reactive X operator "FlatMapFirst"](http://reactivex.io/documentation/operators/flatmap.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func flatMapFirst<Interface: SignalInterface>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> Interface) -> Signal<Interface.OutputValue> {
		return transformFlatten(initialState: false, closePropagation: .errors, context: context) { (s: inout Bool, v: OutputValue, mergedInput: SignalMergedInput<Interface.OutputValue>) in
			if !s {
				mergedInput.add(try processor(v), closePropagation: .errors, removeOnDeactivate: true)
				s = true
			}
		}
	}
	
	/// Implementation of [Reactive X operator "FlatMapLatest"](http://reactivex.io/documentation/operators/flatmap.html)
	///
	/// See also `switchLatest`
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func flatMapLatest<Interface: SignalInterface>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> Interface) -> Signal<Interface.OutputValue> {
		return transformFlatten(initialState: nil, closePropagation: .errors, context: context) { (s: inout Signal<Interface.OutputValue>?, v: OutputValue, mergedInput: SignalMergedInput<Interface.OutputValue>) in
			if let existing = s {
				mergedInput.remove(existing)
			}
			let next = try processor(v).signal
			mergedInput.add(next, closePropagation: .errors, removeOnDeactivate: true)
			s = next
		}
	}
	
	/// Implementation of [Reactive X operator "FlatMap"](http://reactivex.io/documentation/operators/flatmap.html)
	///
	/// - Parameters:
	///   - initialState: an initial value for a state parameter that will be passed to the processor on each iteration.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is merged into a single stream
	public func flatMap<Interface: SignalInterface, V>(initialState: V, context: Exec = .direct, _ processor: @escaping (inout V, OutputValue) throws -> Interface) -> Signal<Interface.OutputValue> {
		return transformFlatten(initialState: initialState, closePropagation: .errors, context: context) { (s: inout V, v: OutputValue, mergedInput: SignalMergedInput<Interface.OutputValue>) in
			mergedInput.add(try processor(&s, v), closePropagation: .errors, removeOnDeactivate: true)
		}
	}
	
	/// Implementation of [Reactive X operator "ConcatMap"](http://reactivex.io/documentation/operators/flatmap.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a new `Signal`
	/// - Returns: a signal where every value from every `Signal` output by `processor` is serially concatenated into a single stream
	public func concatMap<Interface: SignalInterface>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> Interface) -> Signal<Interface.OutputValue> {
		return transformFlatten(initialState: 0, closePropagation: .errors, context: context) { (index: inout Int, v: OutputValue, mergedInput: SignalMergedInput<(Int, Result<Interface.OutputValue, SignalEnd>)>) in
			mergedInput.add(try processor(v).transform { (r: Result<Interface.OutputValue, SignalEnd>) -> Signal<Result<Interface.OutputValue, SignalEnd>>.Next in
				switch r {
				case .success:
					return .value(r)
				case .failure(let e):
					return .value(r, end: e)
				}
			}.map { [index] (r: Result<Interface.OutputValue, SignalEnd>) -> (Int, Result<Interface.OutputValue, SignalEnd>) in (index, r) }, closePropagation: .errors, removeOnDeactivate: true)
			index += 1
		}.transform(initialState: (0, Array<Array<Result<Interface.OutputValue, SignalEnd>>>())) { (state: inout (completed: Int, buffers: Array<Array<Result<Interface.OutputValue, SignalEnd>>>), result: Result<(Int, Result<Interface.OutputValue, SignalEnd>), SignalEnd>) -> Signal<Interface.OutputValue>.Next in
			switch result {
			case .success(let index, .success(let v)):
				// We can send results for the first incomplete signal without buffering
				if index == state.completed {
					return .value(v)
				} else {
					// Make sure we have enough buffers
					while index >= state.buffers.count {
						state.buffers.append([])
					}
					
					// Buffer the result
					state.buffers[index].append(Result<Interface.OutputValue, SignalEnd>.success(v))
					return .none
				}
			case .success(let index, .failure(let e)):
				// If its an error, try to send some more buffers
				if index == state.completed {
					state.completed += 1
					var results = [Signal<Interface.OutputValue>.Result]()
					for i in state.completed..<state.buffers.count {
						for j in state.buffers[i] where !j.isFailure {
							results.append(j)
						}
						
						let incomplete = state.buffers[i].last?.isFailure != true
						state.buffers[i].removeAll()
						if incomplete {
							break
						}
						state.completed += 1
					}
					return .array(results)
				} else {
					// If we're not up to that buffer, just record the error
					state.buffers[index].append(Result<Interface.OutputValue, SignalEnd>.failure(e))
					return .none
				}
			case .failure(let error): return .end(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "GroupBy"](http://reactivex.io/documentation/operators/groupby.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs the "key" for the output `Signal`
	/// - Returns: a parent `Signal` where values are tuples of a "key" and a child `Signal` that will contain all values from `self` associated with that "key".
	public func groupBy<U: Hashable>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> U) -> Signal<(U, Signal<OutputValue>)> {
		return self.transform(initialState: Dictionary<U, SignalInput<OutputValue>>(), context: context) { (outputs: inout Dictionary<U, SignalInput<OutputValue>>, r: Result<OutputValue, SignalEnd>) -> Signal<(U, Signal<OutputValue>)>.Next in
			switch r {
			case .success(let v):
				do {
					let u = try processor(v)
					if let o = outputs[u] {
						o.send(value: v)
						return .none
					} else {
						let (input, preCachedSignal) = Signal<OutputValue>.create()
						let s = preCachedSignal.cacheUntilActive()
						input.send(value: v)
						outputs[u] = input
						return .value((u, s))
					}
				} catch {
					return .error(error)
				}
			case .failure(let e):
				outputs.forEach { tuple in tuple.value.send(end: e) }
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Map"](http://reactivex.io/documentation/operators/map.html)
	///
	/// - Parameters:
	///   - keyPath: selects a child value to emit
	/// - Returns: a `Signal` where all the values have been transformed by the key path.
	public func keyPath<U>(_ keyPath: KeyPath<OutputValue, U>) -> Signal<U> {
		return transform { (r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v): return .value(v[keyPath: keyPath])
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Map"](http://reactivex.io/documentation/operators/map.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a value for the output `Signal`
	/// - Returns: a `Signal` where all the values have been transformed by the `processor`. Any error is emitted in the output without change.
	public func map<U>(context: Exec = .direct, _ processor: @escaping (OutputValue) throws -> U) -> Signal<U> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v): return .single(Result<U, Error> { try processor(v) }.mapError(SignalEnd.other))
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Map"](http://reactivex.io/documentation/operators/map.html)
	///
	/// - Parameters:
	///   - initialState: an initial value for a state parameter that will be passed to the processor on each iteration.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: for each value emitted by `self`, outputs a value for the output `Signal`
	/// - Returns: a `Signal` where all the values have been transformed by the `processor`. Any error is emitted in the output without change.
	public func map<U, V>(initialState: V, context: Exec = .direct, _ processor: @escaping (inout V, OutputValue) throws -> U) -> Signal<U> {
		return transform(initialState: initialState, context: context) { (s: inout V, r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v): return .single(Result<U, Error> { try processor(&s, v) }.mapError(SignalEnd.other))
			case .failure(let e): return .end(e)
			}
		}
	}

	/// Implementation of [Reactive X operator "Map"](http://reactivex.io/documentation/operators/map.html) that offers a separate transformation for "activation" values.
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - activation: processing closure for activation values
	///   - remainder: processing closure for all normal (non-activation) values
	/// - Returns: a `Signal` where all the activation values have been transformed by `activation` and all other values have been transformed by `remained`. Any error is emitted in the output without change.
	public func mapActivation<U>(select: SignalActivationSelection, context: Exec = .direct, activation: @escaping (OutputValue) throws -> U, remainder: @escaping (OutputValue) throws -> U) -> Signal<U> {
		return compactMapActivation(select: select, context: context, activation: activation, remainder: remainder)
	}
	
	/// Implementation of [Reactive X operator "Map"](http://reactivex.io/documentation/operators/map.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: used to transform the closing error 
	/// - Returns: when an error is emitted from `self`, emits the result returned from passing that error into `processor`. All values emitted normally.
	public func mapErrors(context: Exec = .direct, _ processor: @escaping (SignalEnd) -> SignalEnd) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v): return .value(v)
			case .failure(let e): return .end(processor(e))
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Scan"](http://reactivex.io/documentation/operators/scan.html)
	///
	/// See also: `Signal.reduce` which returns a `SignalMulti` and whose processor has the signature `(inout U, OutputValue) -> Void` to make in-place transformations easier.
	/// See also: `aggregate` which performs the equivalent of scan over the entire sequence before emitting a single value.
	///
	/// - Parameters:
	///   - initialState: an initial value for a state parameter that will be passed to the processor on each iteration.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: takes the most recently emitted value and the most recent value from `self` and returns the next emitted value
	/// - Returns: a `Signal` where the result from each invocation of `processor` are emitted
	public func scan<U>(initialState: U, context: Exec = .direct, _ processor: @escaping (U, OutputValue) throws -> U) -> Signal<U> {
		return transform(initialState: initialState, context: context) { (accumulated: inout U, r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v):
				do {
					accumulated = try processor(accumulated, v)
					return .value(accumulated)
				} catch {
					return .error(error)
				}
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Window"](http://reactivex.io/documentation/operators/window.html) for non-overlapping/no-gap buffers.
	///
	/// - Note: equivalent to "buffer" method with same parameters
	///
	/// - Parameter boundaries: when this `Signal` sends a value, the buffer is emitted and cleared
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `boundaries`
	public func window<Interface: SignalInterface>(boundaries: Interface) -> Signal<Signal<OutputValue>> {
		return combine(boundaries, initialState: nil) { (current: inout SignalInput<OutputValue>?, cr: EitherResult2<OutputValue, Interface.OutputValue>) -> Signal<Signal<OutputValue>>.Next in
			switch cr {
			case .result1(.success(let v)):
				if let c = current {
					c.send(value: v)
					return .none
				} else {
					let (i, s) = Signal<OutputValue>.create()
					current = i
					return .value(s.cacheUntilActive(precached: [v]))
				}
			case .result1(.failure(let e)):
				return .end(e)
			case .result2(.success):
				_ = current?.complete()
				current = nil
				return .none
			case .result2(.failure(let e)):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Window"](http://reactivex.io/documentation/operators/window.html) for buffers with overlap or gaps between.
	///
	/// - Note: equivalent to "buffer" method with same parameters
	///
	/// - Parameter windows: a "windows" signal (one that describes a series of times and durations). Each value `Signal` in the stream starts a new buffer and when the value `Signal` closes, the buffer is emitted.
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `windows`
	public func window<Interface: SignalInterface>(windows: Interface) -> Signal<Signal<OutputValue>> where Interface.OutputValue: SignalInterface {
		return combine(windows.valueDurations { s in s }, initialState: [Int: SignalInput<OutputValue>]()) { (children: inout [Int: SignalInput<OutputValue>], cr: EitherResult2<OutputValue, (Int, Interface.OutputValue?)>) -> Signal<Signal<OutputValue>>.Next in
			switch cr {
			case .result1(.success(let v)):
				for index in children.keys {
					if let c = children[index] {
						c.send(value: v)
					}
				}
				return .none
			case .result1(.failure(let e)):
				return .end(e)
			case .result2(.success(let index, .some)):
				let (i, s) = Signal<OutputValue>.create()
				children[index] = i
				return .value(s)
			case .result2(.success(let index, .none)):
				if let c = children[index] {
					c.complete()
					children.removeValue(forKey: index)
				}
				return .none
			case .result2(.failure(let e)):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Window"](http://reactivex.io/documentation/operators/window.html) for buffers of fixed length and a fixed number of values separating starts.
	///
	/// - Note: equivalent to "buffer" method with same parameters
	///
	/// - Parameters:
	///   - count: the number of separate values to accumulate before emitting an array of values
	///   - skip: the stride between the start of each new buffer (can be smaller than `count`, resulting in overlapping buffers)
	/// - Returns: a signal where the values are arrays of length `count` of values from `self`, with start values separated by `skip`
	public func window(count: UInt, skip: UInt) -> Signal<Signal<OutputValue>> {
		let multi = multicast()
		
		// Create the two listeners to the "multi" signal carefully so that the window signal is *first* (so it reaches the buffer before the value signal)
		let windowSignal = multi.stride(count: Int(skip)).map { v in
			// `count - 1` is the index of the count-th element but since `valuesSignal` will resolve before this, we need to fire 1 element sooner, hence `count - 2`
			multi.elementAt(count - 2).ignoreElements(outputType: OutputValue.self)
		}
		
		return multi.window(windows: windowSignal)
	}
	
	/// Implementation of [Reactive X operator "Window"](http://reactivex.io/documentation/operators/window.html) for non-overlapping, periodic buffer start times and possibly limited buffer sizes.
	///
	/// - Note: equivalent to "buffer" method with same parameters
	///
	/// - Parameters:
	///   - interval: the number of seconds between the start of each buffer
	///   - count: the number of separate values to accumulate before emitting an array of values
	///   - continuous: if `true` (default), the `timeshift` periodic timer runs continuously (empty buffers may be emitted if a timeshift elapses without any source signals). If `false`, the periodic timer does start until the first value is received from the source and the periodic timer is paused when a buffer is emitted.
	///   - context: context where the timer will run
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `windows`
	public func window(interval: DispatchTimeInterval, count: Int = Int.max, continuous: Bool = true, context: Exec = .direct) -> Signal<Signal<OutputValue>> {
		let multi = multicast()
		
		// Create the two listeners to the "multi" signal carefully so that the raw signal is *first* (so it reaches the buffer before the boundary signal)
		let valuesSignal = multi.map { v in v }
		let boundarySignal = multi.timedCountedBoundary(interval: interval, count: count, continuous: continuous, context: context)
		
		return valuesSignal.window(boundaries: boundarySignal)
	}
	
	/// Implementation of [Reactive X operator "Window"](http://reactivex.io/documentation/operators/window.html) for non-overlapping buffers of fixed length.
	///
	/// - Note: this is just a convenience wrapper around `buffer(count:skip:behavior)` where `skip` equals `count`.
	/// - Note: equivalent to "buffer" method with same parameters
	///
	/// - Parameter count: the number of separate values to accumulate before emitting an array of values
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `count`
	public func window(count: UInt) -> Signal<Signal<OutputValue>> {
		return window(count: count, skip: count)
	}
	
	/// Implementation of [Reactive X operator "Window"](http://reactivex.io/documentation/operators/window.html) for periodic buffer start times and fixed duration buffers.
	///
	/// - Note: this is just a convenience wrapper around `buffer(windows:behaviors)` where the `windows` signal contains `timerSignal` signals contained in a `Signal.interval` signal.
	/// - Note: equivalent to "buffer" method with same parameters
	///
	/// - Parameters:
	///   - interval: the duration of each buffer, in seconds
	///   - timeshift: the number of seconds between the start of each buffer (if smaller than `interval`, buffers will overlap).
	///   - context: context where the timer will run
	/// - Returns: a signal where the values are arrays of values from `self`, accumulated according to `windows`
	public func window(interval: DispatchTimeInterval, timeshift: DispatchTimeInterval, context: Exec = .direct) -> Signal<Signal<OutputValue>> {
		return window(windows: Signal.interval(timeshift, initial: .seconds(0), context: context).map { v in Signal<Void>.timer(interval: interval, context: context) })
	}
	
	/// Implementation of [Reactive X operator "Debounce"](http://reactivex.io/documentation/operators/debounce.html)
	///
	/// - Parameters:
	///   - interval: the duration over which to drop values.
	///   - flushOnClose: if true, then any buffered value is sent before closing, if false (default) then the buffered value is discarded when a close occurs
	///   - context: context where the timer will run
	/// - Returns: a signal where values are emitted after a `interval` but only if no another value occurs during that `interval`.
	public func debounce(interval: DispatchTimeInterval, flushOnClose: Bool = false, context: Exec = .direct) -> Signal<OutputValue> {
		let serialContext = context.serialized()
		let (mergedInput, signal) = Signal<OutputValue>.createMergedInput()
		let intermediate = transform(initialState: nil, context: serialContext) { (timer: inout Signal<OutputValue>?, result: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch result {
			case .success(let v):
				if let oldTimer = timer {
					mergedInput.remove(oldTimer)
				}
				let newTimer = Signal<OutputValue>.timer(interval: interval, value: v, context: serialContext)
				mergedInput.add(newTimer, closePropagation: .none, removeOnDeactivate: true)
				timer = newTimer
				return .none
			case .failure(let e):
				return .end(e)
			}
		}
		mergedInput.add(intermediate, closePropagation: .all, removeOnDeactivate: false)
		return signal
	}
	
	/// Implementation of [Reactive X operator "throttleFirst"](http://reactivex.io/documentation/operators/sample.html)
	///
	/// - Note: this is largely the reverse of `debounce`.
	///
	/// - Parameters:
	///   - interval: the duration over which to drop values.
	///   - context: context where the timer will run
	/// - Returns: a signal where a timer is started when a value is received and emitted and further values received within that `interval` will be dropped.
	public func throttleFirst(interval: DispatchTimeInterval, context: Exec = .direct) -> Signal<OutputValue> {
		let timerQueue = context.serialized()
		var timer: Lifetime? = nil
		return transform(initialState: nil, context: timerQueue) { (cleanup: inout OnDelete?, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			cleanup = cleanup ?? OnDelete {
				timer = nil
			}
			
			switch r {
			case .failure(let e):
				return .end(e)
			case .success(let v) where timer == nil:
				timer = timerQueue.singleTimer(interval: interval) {
					timer = nil
				}
				return .value(v)
			case .success: return .none
			}
		}
	}
}

extension SignalInterface where OutputValue: Hashable {
	/// Implementation of [Reactive X operator "distinct"](http://reactivex.io/documentation/operators/distinct.html)
	///
	/// - Returns: a signal where all values received are remembered and only values not previously received are emitted.
	public func distinct() -> Signal<OutputValue> {
		return transform(initialState: Set<OutputValue>()) { (previous: inout Set<OutputValue>, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				if !previous.contains(v) {
					previous.insert(v)
					return .value(v)
				}
				return .none
			case .failure(let e):
				return .end(e)
			}
		}
	}
}

extension SignalInterface where OutputValue: Equatable {
	/// Implementation of [Reactive X operator "distinct"](http://reactivex.io/documentation/operators/distinct.html)
	///
	/// - Returns: a signal that emits the first value but then emits subsequent values only when they are different to the previous value.
	public func distinctUntilChanged() -> Signal<OutputValue> {
		return transform(initialState: nil) { (previous: inout OutputValue?, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				if previous != v {
					previous = v
					return .value(v)
				}
				return .none
			case .failure(let e):
				return .end(e)
			}
		}
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "distinct"](http://reactivex.io/documentation/operators/distinct.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `comparator` will be evaluated (default: .direct).
	///   - comparator: a function taking two parameters (the previous and current value in the signal) which should return `false` to indicate the current value should be emitted.
	/// - Returns: a signal that emits the first value but then emits subsequent values only if the function `comparator` returns `false` when passed the previous and current values.
	public func distinctUntilChanged(context: Exec = .direct, compare: @escaping (OutputValue, OutputValue) throws -> Bool) -> Signal<OutputValue> {
		return transform(initialState: nil) { (previous: inout OutputValue?, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				do {
					if let p = previous, try compare(p, v) {
						previous = v
						return .none
					} else {
						previous = v
						return .value(v)
					}
				} catch {
					return .error(error)
				}
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "elementAt"](http://reactivex.io/documentation/operators/elementat.html)
	///
	/// - Parameter index: identifies the element to be emitted.
	/// - Returns: a signal that emits the zero-indexed element identified by `index` and then closes.
	public func elementAt(_ index: UInt) -> Signal<OutputValue> {
		return transform(initialState: 0, context: .direct) { (curr: inout UInt, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v) where curr == index:
				return .value(v, end: .complete)
			case .success:
				curr += 1
				return .none
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "filter"](http://reactivex.io/documentation/operators/filter.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `matching` will be evaluated (default: .direct).
	///   - matching: a function which is passed the current value and should return `true` to indicate the value should be emitted.
	/// - Returns: a signal that emits received values only if the function `matching` returns `true` when passed the value.
	public func filter(context: Exec = .direct, matching: @escaping (OutputValue) throws -> Bool) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try matching(v): return .value(v)
				case .success: return .none
				case .failure(let e): return .end(e)
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "ofType"](http://reactivex.io/documentation/operators/filter.html)
	///
	/// - Parameters:
	///   - type: values will be filtered to this type (NOTE: only the *static* type of this parameter is considered – if the runtime type is more specific, that will be ignored).
	/// - Returns: a signal that emits received values only if the value can be dynamically cast to the type `U`, specified statically by `type`.
	public func ofType<U>(_ type: U.Type) -> Signal<U> {
		return self.transform(initialState: 0) { (curr: inout Int, r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			switch r {
			case .success(let v as U): return .value(v)
			case .success: return .none
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "first"](http://reactivex.io/documentation/operators/first.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `matching` will be evaluated (default: .direct).
	///   - matching: run for each value until it returns `true`
	/// - Returns: a signal that, when an error is received, emits the first value (if any) in the signal where `matching` returns `true` when invoked with the value, followed by the error.
	public func first(context: Exec = .direct, matching: @escaping (OutputValue) throws -> Bool = { _ in true }) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try matching(v): return .value(v, end: .complete)
				case .success: return .none
				case .failure(let e): return .end(e)
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "single"](http://reactivex.io/documentation/operators/first.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `matching` will be evaluated (default: .direct).
	///   - matching: run for each value
	/// - Returns: a signal that, if a single value in the sequence, when passed to `matching` returns `true`, then that value will be returned, followed by a SignalEnd.complete when the input signal closes (otherwise a SignalEnd.complete will be emitted without emitting any prior values).
	public func single(context: Exec = .direct, matching: @escaping (OutputValue) throws -> Bool = { _ in true }) -> Signal<OutputValue> {
		return transform(initialState: nil, context: context) { (state: inout (firstMatch: OutputValue, unique: Bool)?, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try matching(v):
					if let s = state {
						state = (firstMatch: s.firstMatch, unique: false)
					} else {
						state = (firstMatch: v, unique: true)
					}
					return .none
				case .success:
					return .none
				case .failure(let e):
					if let s = state, s.unique == true {
						return .value(s.firstMatch, end: e)
					} else {
						return .end(e)
					}
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "ignoreElements"](http://reactivex.io/documentation/operators/ignoreelements.html)
	///
	/// - Returns: a signal that emits the input error, when received, otherwise ignores all values.
	public func ignoreElements<U>(outputType: U.Type = U.self) -> Signal<U> {
		return transform { (r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			if case .failure(let e) = r {
				return .end(e)
			} else {
				return .none
			}
		}
	}
	
	/// Implementation of [Reactive X operator "last"](http://reactivex.io/documentation/operators/last.html)
	///
	/// - Parameters:
	///   - context: the `Exec` where `matching` will be evaluated (default: .direct).
	///   - matching: run for each value
	/// - Returns: a signal that, when an error is received, emits the last value (if any) in the signal where `matching` returns `true` when invoked with the value, followed by the error.
	public func last(context: Exec = .direct, matching: @escaping (OutputValue) throws -> Bool = { _ in true }) -> Signal<OutputValue> {
		return transform(initialState: nil, context: context) { (last: inout OutputValue?, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try matching(v):
					last = v
					return .none
				case .success:
					return .none
				case .failure(let e):
					if let l = last {
						return .value(l, end: e)
					} else {
						return .end(e)
					}
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "sample"](http://reactivex.io/documentation/operators/sample.html)
	///
	/// See also: `debounce` is the equivalent where the sampling interval is time based
	/// See also: `withLatestFrom` always emits, even when the sampled signal hasn't emitted another value during the interval
	///
	/// - Parameter trigger: instructs the result to emit the last value from `self`
	/// - Returns: a signal that, when a value is received from `trigger`, emits the last value (if any) received from `self`.
	public func sample<Interface: SignalInterface>(_ trigger: Interface) -> Signal<OutputValue> {
		return combine(trigger, initialState: nil, context: .direct) { (last: inout OutputValue?, c: EitherResult2<OutputValue, Interface.OutputValue>) -> Signal<OutputValue>.Next in
			switch (c, last) {
			case (.result1(.success(let v)), _):
				last = v
				return .none
			case (.result1(.failure(let e)), _):
				return .end(e)
			case (.result2(.success), .some(let l)):
				last = nil
				return .value(l)
			case (.result2(.success), _):
				return .none
			case (.result2(.failure(let e)), _):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "sample"](http://reactivex.io/documentation/operators/sample.html)
	///
	/// - Parameter trigger: instructs the result to emit the last value from `self`
	/// - Returns: a signal that, when a value is received from `trigger`, emits the last value (if any) received from `self`.
	public func throttleFirst<Interface: SignalInterface>(_ trigger: Interface) -> Signal<OutputValue> {
		return combine(trigger, initialState: nil, context: .direct) { (last: inout OutputValue?, c: EitherResult2<OutputValue, Interface.OutputValue>) -> Signal<OutputValue>.Next in
			switch (c, last) {
			case (.result1(.success(let v)), nil):
				last = v
				return .none
			case (.result1(.success), _):
				return .none
			case (.result1(.failure(let e)), _):
				return .end(e)
			case (.result2(.success), .some(let l)):
				last = nil
				return .value(l)
			case (.result2(.success), _):
				return .none
			case (.result2(.failure(let e)), _):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "skip"](http://reactivex.io/documentation/operators/skip.html)
	///
	/// - Parameter count: the number of values from the start of `self` to drop
	/// - Returns: a signal that drops `count` values from `self` then mirrors `self`.
	public func skip(_ count: Int) -> Signal<OutputValue> {
		return transform(initialState: 0) { (progressCount: inout Int, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v) where progressCount >= count: return .value(v)
			case .success:
				progressCount = progressCount + 1
				return .none
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "skipLast"](http://reactivex.io/documentation/operators/skiplast.html)
	///
	/// - Parameter count: the number of values from the end of `self` to drop
	/// - Returns: a signal that buffers `count` values from `self` then for each new value received from `self`, emits the oldest value in the buffer. When `self` closes, all remaining values in the buffer are discarded.
	public func skipLast(_ count: Int) -> Signal<OutputValue> {
		return transform(initialState: Array<OutputValue>()) { (buffer: inout Array<OutputValue>, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				buffer.append(v)
				if buffer.count > count {
					return .value(buffer.removeFirst())
				} else {
					return .none
				}
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "skip"](http://reactivex.io/documentation/operators/skip.html)
	///
	/// - Parameter count: the number of values from the start of `self` to emit
	/// - Returns: a signal that emits `count` values from `self` then closes.
	public func take(_ count: Int) -> Signal<OutputValue> {
		return transform(initialState: 0) { (progressCount: inout Int, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			progressCount = progressCount + 1
			switch r {
			case .success(let v) where progressCount >= count: return .value(v, end: .complete)
			case .success(let v): return .value(v)
			case .failure(let e): return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "skipLast"](http://reactivex.io/documentation/operators/skiplast.html)
	///
	/// - Parameter count: the number of values from the end of `self` to emit
	/// - Returns: a signal that buffers `count` values from `self` then for each new value received from `self`, drops the oldest value in the buffer. When `self` closes, all values in the buffer are emitted, followed by the close.
	public func takeLast(_ count: Int) -> Signal<OutputValue> {
		return transform(initialState: Array<OutputValue>()) { (buffer: inout Array<OutputValue>, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				buffer.append(v)
				if buffer.count > count {
					buffer.removeFirst()
				}
				return .none
			case .failure(let e):
				return .values(sequence: buffer, end: e)
			}
		}
	}
}

extension SignalInterface {
	/// - Note: the [Reactive X operators "And", "Then" and "When"](http://reactivex.io/documentation/operators/and-then-when.html) are considered unnecessary, given the slightly different implementation of `CwlSignal.Signal.zip` which produces tuples (rather than producing a non-structural type) and is hence equivalent to `and`+`then`.
}

extension SignalInterface {
	/// Implementation similar to [Reactive X operator "sample"](http://reactivex.io/documentation/operators/sample.html) except that the output is sent every time self emits, not just when sample has changed since self last emitted.
	///
	/// See also: `combineLatest`, `sample` and `throttleFirst` which have similar but slightly different emitting scenarios.
	///
	/// - Parameter sample: the latest value from this signal will be emitted whenever `self` emits
	/// - Returns: a signal that emits the latest value from `sample` each time `self` emits
	public func withLatestFrom<Interface: SignalInterface>(_ sample: Interface) -> Signal<Interface.OutputValue> {
		return combine(sample, initialState: nil, context: .direct) { (last: inout Interface.OutputValue?, c: EitherResult2<OutputValue, Interface.OutputValue>) -> Signal<Interface.OutputValue>.Next in
			switch (c, last) {
			case (.result1(.success), .some(let l)): return .value(l)
			case (.result1(.success), _): return .none
			case (.result1(.failure(let e)), _): return .end(e)
			case (.result2(.success(let v)), _):
				last = v
				return .none
			case (.result2(.failure(let e)), _): return .end(e)
			}
		}
	}
	
	/// Implementation similar to [Reactive X operator "sample"](http://reactivex.io/documentation/operators/sample.html) except that a function is run to generate the emitted value each time self emits. The function is passed the value emitted from `self` and the last emitted value from the `sample` signal parameter.
	///
	/// See also: `combineLatest`, `sample` and `throttleFirst` which have similar but slightly different emitting scenarios.
	///
	/// - Parameter sample: a signal whose latest value will be used each time `self` emits
	/// - Parameter processor: produces the outputs values
	/// - Returns: a signal that, when a value is received from `trigger`, emits the result or performing `processor`.
	public func withLatestFrom<Interface: SignalInterface, R>(_ sample: Interface, context: Exec = .direct, _ processor: @escaping (OutputValue, Interface.OutputValue) throws -> R) -> Signal<R> {
		return combine(sample, initialState: nil, context: context) { (last: inout Interface.OutputValue?, c: EitherResult2<OutputValue, Interface.OutputValue>) -> Signal<R>.Next in
			switch (c, last) {
			case (.result1(.success(let left)), .some(let right)):
				do {
					return .value(try processor(left, right))
				} catch {
					return .error(error)
				}
			case (.result1(.success), _): return .none
			case (.result1(.failure(let e)), _): return .end(e)
			case (.result2(.success(let v)), _):
				last = v
				return .none
			case (.result2(.failure(let e)), _): return .end(e)
			}
		}
	}

	/// Implementation of [Reactive X operator "combineLatest"](http://reactivex.io/documentation/operators/combinelatest.html) for two observed signals.
	///
	/// - Parameters:
	///   - second: an observed signal.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: invoked with the most recent values of the observed signals (or nil if a signal has not yet emitted a value) when any of the observed signals emits a value
	/// - Returns: a signal that emits the values from the processor and closes when any of the observed signals closes
	public func combineLatestWith<U: SignalInterface, V>(_ second: U, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue) throws -> V) -> Signal<V> {
		return combine(second, initialState: (nil, nil), context: context) { (state: inout (OutputValue?, U.OutputValue?), r: EitherResult2<OutputValue, U.OutputValue>) -> Signal<V>.Next in
			switch r {
			case .result1(.success(let v)): state = (v, state.1)
			case .result2(.success(let v)): state = (state.0, v)
			case .result1(.failure(let e)): return .end(e)
			case .result2(.failure(let e)): return .end(e)
			}
			if let v0 = state.0, let v1 = state.1 {
				do {
					return .value(try processor(v0, v1))
				} catch {
					return .error(error)
				}
			} else {
				return .none
			}
		}
	}

	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func combineLatest<U: SignalInterface, V>(_ second: U, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue) throws -> V) -> Signal<V> {
		return combineLatestWith(second, context: context, processor)
	}
	
	public static func combineLatest<U: SignalInterface, V>(_ first: Self, _ second: U, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue) throws -> V) -> Signal<V> {
		return first.combineLatestWith(second, context: context, processor)
	}
	
	/// Implementation of [Reactive X operator "combineLatest"](http://reactivex.io/documentation/operators/combinelatest.html) for three observed signals.
	///
	/// - Parameters:
	///   - second: an observed signal.
	///   - third: an observed signal.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: invoked with the most recent values of the observed signals (or nil if a signal has not yet emitted a value) when any of the observed signals emits a value
	/// - Returns: a signal that emits the values from the processor and closes when any of the observed signals closes
	public func combineLatestWith<U: SignalInterface, V: SignalInterface, W>(_ second: U, _ third: V, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue) throws -> W) -> Signal<W> {
		return combine(second, third, initialState: (nil, nil, nil), context: context) { (state: inout (OutputValue?, U.OutputValue?, V.OutputValue?), r: EitherResult3<OutputValue, U.OutputValue, V.OutputValue>) -> Signal<W>.Next in
			switch r {
			case .result1(.success(let v)): state = (v, state.1, state.2)
			case .result2(.success(let v)): state = (state.0, v, state.2)
			case .result3(.success(let v)): state = (state.0, state.1, v)
			case .result1(.failure(let e)): return .end(e)
			case .result2(.failure(let e)): return .end(e)
			case .result3(.failure(let e)): return .end(e)
			}
			if let v0 = state.0, let v1 = state.1, let v2 = state.2 {
				do {
					return .value(try processor(v0, v1, v2))
				} catch {
					return .error(error)
				}
			} else {
				return .none
			}
		}
	}

	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func combineLatest<U: SignalInterface, V: SignalInterface, W>(_ second: U, _ third: V, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue) throws -> W) -> Signal<W> {
		return combineLatestWith(second, third, context: context, processor)
	}
	
	public static func combineLatest<U: SignalInterface, V: SignalInterface, W>(_ first: Self, _ second: U, _ third: V, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue) throws -> W) -> Signal<W> {
		return first.combineLatestWith(second, third, context: context, processor)
	}
	
	/// Implementation of [Reactive X operator "combineLatest"](http://reactivex.io/documentation/operators/combinelatest.html) for four observed signals.
	///
	/// - Note: support for multiple listeners and reactivation is determined by the specified `behavior`.
	///
	/// - Parameters:
	///   - second: an observed signal.
	///   - third: an observed signal.
	///   - fourth: an observed signal.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: invoked with the most recent values of the observed signals (or nil if a signal has not yet emitted a value) when any of the observed signals emits a value
	/// - Returns: a signal that emits the values from the processor and closes when any of the observed signals closes
	public func combineLatestWith<U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(_ second: U, _ third: V, _ fourth: W, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue, W.OutputValue) throws -> X) -> Signal<X> {
		return combine(second, third, fourth, initialState: (nil, nil, nil, nil), context: context) { (state: inout (OutputValue?, U.OutputValue?, V.OutputValue?, W.OutputValue?), r: EitherResult4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>) -> Signal<X>.Next in
			switch r {
			case .result1(.success(let v)): state = (v, state.1, state.2, state.3)
			case .result2(.success(let v)): state = (state.0, v, state.2, state.3)
			case .result3(.success(let v)): state = (state.0, state.1, v, state.3)
			case .result4(.success(let v)): state = (state.0, state.1, state.2, v)
			case .result1(.failure(let e)): return .end(e)
			case .result2(.failure(let e)): return .end(e)
			case .result3(.failure(let e)): return .end(e)
			case .result4(.failure(let e)): return .end(e)
			}
			if let v0 = state.0, let v1 = state.1, let v2 = state.2, let v3 = state.3 {
				do {
					return .value(try processor(v0, v1, v2, v3))
				} catch {
					return .error(error)
				}
			} else {
				return .none
			}
		}
	}

	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func combineLatest<U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(_ second: U, _ third: V, _ fourth: W, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue, W.OutputValue) throws -> X) -> Signal<X> {
		return combineLatestWith(second, third, fourth, context: context, processor)
	}

	public static func combineLatest<U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(_ first: Self, _ second: U, _ third: V, _ fourth: W, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue, W.OutputValue) throws -> X) -> Signal<X> {
		return first.combineLatestWith(second, third, fourth, context: context, processor)
	}
	
	/// Implementation of [Reactive X operator "combineLatest"](http://reactivex.io/documentation/operators/combinelatest.html) for five observed signals.
	///
	/// - Note: support for multiple listeners and reactivation is determined by the specified `behavior`.
	///
	/// - Parameters:
	///   - second: an observed signal.
	///   - third: an observed signal.
	///   - fourth: an observed signal.
	///   - fifth: an observed signal.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: invoked with the most recent values of the observed signals (or nil if a signal has not yet emitted a value) when any of the observed signals emits a value
	/// - Returns: a signal that emits the values from the processor and closes when any of the observed signals closes
	public func combineLatestWith<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface, Y>(_ second: U, _ third: V, _ fourth: W, _ fifth: X, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue) throws -> Y) -> Signal<Y> {
		return combine(second, third, fourth, fifth, initialState: (nil, nil, nil, nil, nil), context: context) { (state: inout (OutputValue?, U.OutputValue?, V.OutputValue?, W.OutputValue?, X.OutputValue?), r: EitherResult5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>) -> Signal<Y>.Next in
			switch r {
			case .result1(.success(let v)): state = (v, state.1, state.2, state.3, state.4)
			case .result2(.success(let v)): state = (state.0, v, state.2, state.3, state.4)
			case .result3(.success(let v)): state = (state.0, state.1, v, state.3, state.4)
			case .result4(.success(let v)): state = (state.0, state.1, state.2, v, state.4)
			case .result5(.success(let v)): state = (state.0, state.1, state.2, state.3, v)
			case .result1(.failure(let e)): return .end(e)
			case .result2(.failure(let e)): return .end(e)
			case .result3(.failure(let e)): return .end(e)
			case .result4(.failure(let e)): return .end(e)
			case .result5(.failure(let e)): return .end(e)
			}
			if let v0 = state.0, let v1 = state.1, let v2 = state.2, let v3 = state.3, let v4 = state.4 {
				do {
					return .value(try processor(v0, v1, v2, v3, v4))
				} catch {
					return .error(error)
				}
			} else {
				return .none
			}
		}
	}

	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func combineLatest<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface, Y>(_ second: U, _ third: V, _ fourth: W, _ fifth: X, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue) throws -> Y) -> Signal<Y> {
		return combineLatestWith(second, third, fourth, fifth, context: context, processor)
	}

	public static func combineLatest<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface, Y>(_ first: Self, _ second: U, _ third: V, _ fourth: W, _ fifth: X, context: Exec = .direct, _ processor: @escaping (OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue) throws -> Y) -> Signal<Y> {
		return first.combineLatestWith(second, third, fourth, fifth, context: context, processor)
	}
	
	public static func combineLatest<S: Sequence>(sequence: S) -> Signal<[OutputValue]> where S.Element: SignalInterface, OutputValue == S.Element.OutputValue {
		let array = Array(sequence)
		let count = array.count
		let indexed = Signal<OutputValue>.indexed(array)
		return indexed.transform(initialState: Array<OutputValue?>(repeating: nil, count: count)) { buffer, result in
			switch result {
			case .success((let offset, let element)):
				buffer[offset] = element
				let compacted = buffer.compactMap { $0 }
				guard compacted.count == count else { return .none }
				return .value(compacted)
			case .failure(let e): return .end(e)
			}
		}
	}

	public static func combineLatest<S: SignalInterface>(_ signals: S...) -> Signal<[OutputValue]> where OutputValue == S.OutputValue {
		return combineLatest(sequence: signals)
	}
	
	/// Implementation of [Reactive X operator "join"](http://reactivex.io/documentation/operators/join.html)
	///
	/// - Parameters:
	///   - withRight: an observed signal
	///   - leftEnd: function invoked when a value is received from `self`. The resulting signal is observed and the time until signal close is treated as a duration "window" that started with the received `self` value.
	///   - rightEnd: function invoked when a value is received from `right`. The resulting signal is observed and the time until signal close is treated as a duration "window" that started with the received `right` value.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: invoked with the corresponding `left` and `right` values when a `left` value is emitted during a `right`->`rightEnd` window or a `right` value is received during a `left`->`leftEnd` window
	/// - Returns: a signal that emits the values from the processor and closes when any of the last of the observed windows closes.
	public func intersect<U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(withRight: U, leftEnd: @escaping (OutputValue) -> V, rightEnd: @escaping (U.OutputValue) -> W, context: Exec = .direct, _ processor: @escaping ((OutputValue, U.OutputValue)) -> X) -> Signal<X> {
		let leftDurations = valueDurations({ t in leftEnd(t).takeWhile { _ in false } })
		let rightDurations = withRight.valueDurations({ u in rightEnd(u).takeWhile { _ in false } })
		let a = leftDurations.combine(rightDurations, initialState: ([Int: OutputValue](), [Int: U.OutputValue]())) { (state: inout (activeLeft: [Int: OutputValue], activeRight: [Int: U.OutputValue]), cr: EitherResult2<(Int, OutputValue?), (Int, U.OutputValue?)>) -> Signal<(OutputValue, U.OutputValue)>.Next in
			switch cr {
			case .result1(.success(let leftIndex, .some(let leftValue))):
				state.activeLeft[leftIndex] = leftValue
				return .array(state.activeRight.sorted { $0.0 < $1.0 }.map { tuple in .success((leftValue, tuple.value)) })
			case .result2(.success(let rightIndex, .some(let rightValue))):
				state.activeRight[rightIndex] = rightValue
				return .array(state.activeLeft.sorted { $0.0 < $1.0 }.map { tuple in .success((tuple.value, rightValue)) })
			case .result1(.success(let leftIndex, .none)):
				state.activeLeft.removeValue(forKey: leftIndex)
				return .none
			case .result2(.success(let rightIndex, .none)):
				state.activeRight.removeValue(forKey: rightIndex)
				return .none
			default:
				return .complete()
			}
		}
		return a.map(context: context, processor)
	}
	
	/// Implementation of [Reactive X operator "groupJoin"](http://reactivex.io/documentation/operators/join.html)
	///
	/// - Parameters:
	///   - withRight: an observed signal.
	///   - leftEnd: function invoked when a value is received from `self`. The resulting signal is observed and the time until signal close is treated as a duration "window" that started with the received `self` value.
	///   - rightEnd: function invoked when a value is received from `right`. The resulting signal is observed and the time until signal close is treated as a duration "window" that started with the received `right` value.
	///   - context: the `Exec` where `processor` will be evaluated (default: .direct).
	///   - processor: when a `left` value is received, this function is invoked with the `left` value and a `Signal` that will emit all the `right` values encountered until the `left`->`leftEnd` window closes. The value returned by this function will be emitted as part of the `Signal` returned from `groupIntersect`.
	/// - Returns: a signal that emits the values from the processor and closes when any of the last of the observed windows closes.
	public func groupIntersect<U: SignalInterface, V: SignalInterface, W: SignalInterface, X>(withRight: U, leftEnd: @escaping (OutputValue) -> V, rightEnd: @escaping (U.OutputValue) -> W, context: Exec = .direct, _ processor: @escaping ((OutputValue, Signal<U.OutputValue>)) -> X) -> Signal<X> {
		let leftDurations = valueDurations({ u in leftEnd(u).takeWhile { _ in false } })
		let rightDurations = withRight.valueDurations({ u in rightEnd(u).takeWhile { _ in false } })
		return leftDurations.combine(rightDurations, initialState: ([Int: SignalInput<U.OutputValue>](), [Int: U.OutputValue]())) { (state: inout (activeLeft: [Int: SignalInput<U.OutputValue>], activeRight: [Int: U.OutputValue]), cr: EitherResult2<(Int, OutputValue?), (Int, U.OutputValue?)>) -> Signal<(OutputValue, Signal<U.OutputValue>)>.Next in
			switch cr {
			case .result1(.success(let leftIndex, .some(let leftValue))):
				let (li, ls) = Signal<U.OutputValue>.create()
				state.activeLeft[leftIndex] = li
				return .value((leftValue, ls.cacheUntilActive(precached: state.activeRight.sorted { $0.0 < $1.0 }.map { $0.value })))
			case .result2(.success(let rightIndex, .some(let rightValue))):
				state.activeRight[rightIndex] = rightValue
				state.activeLeft.sorted { $0.0 < $1.0 }.forEach { tuple in tuple.value.send(value: rightValue) }
				return .none
			case .result1(.success(let leftIndex, .none)):
				_ = state.activeLeft[leftIndex]?.complete()
				state.activeLeft.removeValue(forKey: leftIndex)
				return .none
			case .result2(.success(let rightIndex, .none)):
				state.activeRight.removeValue(forKey: rightIndex)
				return .none
			default:
				return .complete()
			}
		}.map(context: context, processor)
	}
}

extension Signal {	
	/// Implementation of [Reactive X operator "merge"](http://reactivex.io/documentation/operators/merge.html) where the output closes only when the last source closes.
	///
	/// - Parameter sources: a variable parameter list of `Signal<OutputValue>` instances that are merged with `self` to form the result.
	/// - Returns: a signal that emits every value from every `sources` input `signal`.
	public func merge<S: Sequence>(sequence: S) -> Signal<OutputValue> where S.Iterator.Element == Signal<OutputValue> {
		let (mergedInput, sig) = Signal<OutputValue>.createMergedInput(onLastInputClosed: .complete)
		mergedInput.add(signal, closePropagation: .errors)
		for s in sequence {
			mergedInput.add(s, closePropagation: .errors)
		}
		return sig
	}
	
	/// Implementation of [Reactive X operator "merge"](http://reactivex.io/documentation/operators/merge.html) where the output closes only when the last source closes.
	///
	/// NOTE: the signal closes as `SignalComplete.cancelled` when the last output closes. For other closing semantics, use `Signal.mergSetAndSignal` instead.
	///
	/// - Parameter sources: an `Array` where `signal` is merged into the result.
	/// - Returns: a signal that emits every value from every `sources` input `signal`.
	public static func merge<S: Sequence>(sequence: S) -> Signal<OutputValue> where S.Iterator.Element == Signal<OutputValue> {
		let (mergedInput, sig) = Signal<OutputValue>.createMergedInput(onLastInputClosed: .complete)
		var sequenceEmpty = true
		for s in sequence {
			mergedInput.add(s, closePropagation: .errors)
			sequenceEmpty = false
		}
		if sequenceEmpty {
			return Signal<OutputValue>.preclosed()
		}
		return sig
	}
	
	/// Implementation of [Reactive X operator "merge"](http://reactivex.io/documentation/operators/merge.html) where the output closes only when the last source closes.
	///
	/// - Parameter sources: an `Array` where `signal` is merged into the result.
	/// - Returns: a signal that emits every value from every `sources` input `signal`.
	public static func merge(_ sources: Signal<OutputValue>...) -> Signal<OutputValue> {
		return merge(sequence: sources)
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "merge"](http://reactivex.io/documentation/operators/merge.html) where the output closes only when the last source closes.
	///
	/// - Parameter sources: a variable parameter list of `Signal<OutputValue>` instances that are merged with `self` to form the result.
	/// - Returns: a signal that emits every value from every `sources` input `signal`.
	public func merge(_ sources: Signal<OutputValue>...) -> Signal<OutputValue> {
		let (mergedInput, sig) = Signal<OutputValue>.createMergedInput(onLastInputClosed: .complete)
		mergedInput.add(signal, closePropagation: .errors)
		for s in sources {
			mergedInput.add(s, closePropagation: .errors)
		}
		return sig
	}
	
	/// Implementation of [Reactive X operator "startWith"](http://reactivex.io/documentation/operators/startwith.html)
	///
	/// - Parameter sequence: a sequence of values.
	/// - Returns: a signal that emits every value from `sequence` immediately before it starts mirroring `self`.
	public func startWith<S: Sequence>(sequence: S) -> Signal<OutputValue> where S.Iterator.Element == OutputValue {
		return Signal.from(sequence).combine(signal, initialState: false) { (alreadySent: inout Bool, r: EitherResult2<OutputValue, OutputValue>) -> Signal<OutputValue>.Next in
			switch r {
			case .result1(.success(let v)):
				if !alreadySent {
					return .value(v)
				} else {
					return .none
				}
			case .result1(.failure):
				alreadySent = true
				return .none
			case .result2(.success(let v)):
				if !alreadySent {
					alreadySent = true
					return .values(sequence: Array(sequence).appending(v))
				} else {
					return .value(v)
				}
			case .result2(.failure(let e)):
				if !alreadySent {
					alreadySent = true
					return .values(sequence: sequence, end: e)
				} else {
					return .end(e)
				}
			}
		}
	}
	
	/// Implementation of [Reactive X operator "startWith"](http://reactivex.io/documentation/operators/startwith.html)
	///
	/// - Parameter value: a value.
	/// - Returns: a signal that emits the value immediately before it starts mirroring `self`.
	public func startWith(_ values: OutputValue...) -> Signal<OutputValue> {
		return startWith(sequence: values)
	}
	
	/// Implementation of [Reactive X operator "endWith"](http://reactivex.io/documentation/operators/endwith.html)
	///
	/// - Returns: a signal that emits every value from `sequence` on activation and then mirrors `self`.
	public func endWith<U: Sequence>(sequence: U, conditional: @escaping (SignalEnd) -> SignalEnd? = { e in e }) -> Signal<OutputValue> where U.Iterator.Element == OutputValue {
		return transform() { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v): return .value(v)
			case .failure(let e):
				if let newEnd = conditional(e) {
					return .values(sequence: sequence, end: newEnd)
				} else {
					return .end(e)
				}
			}
		}
	}
	
	/// Implementation of [Reactive X operator "endWith"](http://reactivex.io/documentation/operators/endwith.html)
	///
	/// - Returns: a signal that emits every value from `sequence` on activation and then mirrors `self`.
	public func endWith(_ values: OutputValue..., conditional: @escaping (Error) -> Error? = { e in e }) -> Signal<OutputValue> {
		return endWith(sequence: values)
	}

	/// Implementation of [Reactive X operator "switch"](http://reactivex.io/documentation/operators/switch.html)
	///
	/// See also: `flatMapLatest` (emits values from the latest `Signal` to start emitting)
	///
	/// - Parameter signal: each of the inner signals emitted by this outer signal is observed, with the most recent signal emitted from the result
	/// - Returns: a signal that emits the values from the latest `Signal` emitted by `signal`
	public func switchLatest<U>() -> Signal<U> where OutputValue: SignalInterface, OutputValue.OutputValue == U {
		return transformFlatten(initialState: nil, closePropagation: .errors) { (latest: inout Signal<U>?, next: OutputValue, mergedInput: SignalMergedInput<U>) in
			if let l = latest {
				mergedInput.remove(l)
			}
			let s = next.signal
			mergedInput.add(s, closePropagation: .errors, removeOnDeactivate: true)
			latest = s
		}
	}

	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func zip<U: SignalInterface>(_ second: U) -> Signal<(OutputValue, U.OutputValue)> {
		return zipWith(second)
	}

	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameter second: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `with`.
	public static func zip<U: SignalInterface>(_ first: Self, _ second: U) -> Signal<(Self.OutputValue, U.OutputValue)> {
		return first.zipWith(second)
	}
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameter second: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `with`.
	public func zipWith<U: SignalInterface>(_ second: U) -> Signal<(OutputValue, U.OutputValue)> {
		return combine(second, initialState: (Array<OutputValue>(), Array<U.OutputValue>(), false, false)) { (queues: inout (first: Array<OutputValue>, second: Array<U.OutputValue>, firstClosed: Bool, secondClosed: Bool), r: EitherResult2<OutputValue, U.OutputValue>) -> Signal<(OutputValue, U.OutputValue)>.Next in
			switch (r, queues.first.first, queues.second.first) {
			case (.result1(.success(let first)), _, .some(let second)):
				queues.second.removeFirst()
				if (queues.second.isEmpty && queues.secondClosed) {
					return .value((first, second), end: .complete)
				} else {
					return .value((first, second))
				}
			case (.result1(.success(let first)), _, _):
				queues.first.append(first)
				return .none
			case (.result1(.failure(let e)), _, _):
				if queues.first.isEmpty || (queues.second.isEmpty && queues.secondClosed) {
					return .end(e)
				} else {
					queues.firstClosed = true
				}
				return .none
			case (.result2(.success(let second)), .some(let first), _):
				queues.first.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) {
					return .value((first, second), end: .complete)
				} else {
					return .value((first, second))
				}
			case (.result2(.success(let second)), _, _):
				queues.second.append(second)
				return .none
			case (.result2(.failure(let e)), _, _):
				if queues.second.isEmpty || (queues.first.isEmpty && queues.firstClosed) {
					return .end(e)
				} else {
					queues.secondClosed = true
					return .none
				}
			}
		}
	}
	
	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func zip<U: SignalInterface, V: SignalInterface>(_ second: U, _ third: V) -> Signal<(OutputValue, U.OutputValue, V.OutputValue)> {
		return zipWith(second, third)
	}
	
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameters:
	///   - second: another `Signal`
	///   - third: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `second` and `third`.
	public static func zip<U: SignalInterface, V: SignalInterface>(_ first: Self, _ second: U, _ third: V) -> Signal<(Self.OutputValue, U.OutputValue, V.OutputValue)> {
		return first.zipWith(second, third)
	}
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameters:
	///   - second: another `Signal`
	///   - third: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `second` and `third`.
	public func zipWith<U: SignalInterface, V: SignalInterface>(_ second: U, _ third: V) -> Signal<(OutputValue, U.OutputValue, V.OutputValue)> {
		return combine(second, third, initialState: (Array<OutputValue>(), Array<U.OutputValue>(), Array<V.OutputValue>(), false, false, false)) { (queues: inout (first: Array<OutputValue>, second: Array<U.OutputValue>, third: Array<V.OutputValue>, firstClosed: Bool, secondClosed: Bool, thirdClosed: Bool), r: EitherResult3<OutputValue, U.OutputValue, V.OutputValue>) -> Signal<(OutputValue, U.OutputValue, V.OutputValue)>.Next in
			switch (r, queues.first.first, queues.second.first, queues.third.first) {
			case (.result1(.success(let first)), _, .some(let second), .some(let third)):
				queues.second.removeFirst()
				queues.third.removeFirst()
				if (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) {
					return .value((first, second, third), end: .complete)
				} else {
					return .value((first, second, third))
				}
			case (.result1(.success(let first)), _, _, _):
				queues.first.append(first)
				return .none
			case (.result1(.failure(let e)), _, _, _):
				if queues.first.isEmpty || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) {
					return .end(e)
				} else {
					queues.firstClosed = true
					return .none
				}
			case (.result2(.success(let second)), .some(let first), _, .some(let third)):
				queues.first.removeFirst()
				queues.third.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.third.isEmpty && queues.thirdClosed) {
					return .value((first, second, third), end: .complete)
				} else {
					return .value((first, second, third))
				}
			case (.result2(.success(let second)), _, _, _):
				queues.second.append(second)
				return .none
			case (.result2(.failure(let e)), _, _, _):
				if queues.second.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.third.isEmpty && queues.thirdClosed) {
					return .end(e)
				} else {
					queues.secondClosed = true
					return .none
				}
			case (.result3(.success(let third)), .some(let first), .some(let second), _):
				queues.first.removeFirst()
				queues.second.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) {
					return .value((first, second, third), end: .complete)
				} else {
					return .value((first, second, third))
				}
			case (.result3(.success(let third)), _, _, _):
				queues.third.append(third)
				return .none
			case (.result3(.failure(let e)), _, _, _):
				if queues.third.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) {
					return .end(e)
				} else {
					queues.thirdClosed = true
					return .none
				}
			}
		}
	}
	
	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func zip<U: SignalInterface, V: SignalInterface, W: SignalInterface>(_ second: U, _ third: V, _ fourth: W) -> Signal<(OutputValue, U.OutputValue, V.OutputValue, W.OutputValue)> {
		return zipWith(second, third, fourth)
	}
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameters:
	///   - second: another `Signal`
	///   - third: another `Signal`
	///   - fourth: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `second`,`third` and `fourth`.
	public static func zip<U: SignalInterface, V: SignalInterface, W: SignalInterface>(_ first: Self, _ second: U, _ third: V, _ fourth: W) -> Signal<(Self.OutputValue, U.OutputValue, V.OutputValue, W.OutputValue)> {
		return first.zipWith(second, third, fourth)
	}
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameters:
	///   - second: another `Signal`
	///   - third: another `Signal`
	///   - fourth: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `second`,`third` and `fourth`.
	public func zipWith<U: SignalInterface, V: SignalInterface, W: SignalInterface>(_ second: U, _ third: V, _ fourth: W) -> Signal<(OutputValue, U.OutputValue, V.OutputValue, W.OutputValue)> {
		return combine(second, third, fourth, initialState: (Array<OutputValue>(), Array<U.OutputValue>(), Array<V.OutputValue>(), Array<W.OutputValue>(), false, false, false, false)) { (queues: inout (first: Array<OutputValue>, second: Array<U.OutputValue>, third: Array<V.OutputValue>, fourth: Array<W.OutputValue>, firstClosed: Bool, secondClosed: Bool, thirdClosed: Bool, fourthClosed: Bool), r: EitherResult4<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue>) -> Signal<(OutputValue, U.OutputValue, V.OutputValue, W.OutputValue)>.Next in
			switch (r, queues.first.first, queues.second.first, queues.third.first, queues.fourth.first) {
			case (.result1(.success(let first)), _, .some(let second), .some(let third), .some(let fourth)):
				queues.second.removeFirst()
				queues.third.removeFirst()
				queues.fourth.removeFirst()
				if (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .value((first, second, third, fourth), end: .complete)
				} else {
					return .value((first, second, third, fourth))
				}
			case (.result1(.success(let first)), _, _, _, _):
				queues.first.append(first)
				return .none
			case (.result1(.failure(let e)), _, _, _, _):
				if queues.first.isEmpty || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .end(e)
				} else {
					queues.firstClosed = true
					return .none
				}
			case (.result2(.success(let second)), .some(let first), _, .some(let third), .some(let fourth)):
				queues.first.removeFirst()
				queues.third.removeFirst()
				queues.fourth.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .value((first, second, third, fourth), end: .complete)
				} else {
					return .value((first, second, third, fourth))
				}
			case (.result2(.success(let second)), _, _, _, _):
				queues.second.append(second)
				return .none
			case (.result2(.failure(let e)), _, _, _, _):
				if queues.second.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .end(e)
				} else {
					queues.secondClosed = true
					return .none
				}
				
			case (.result3(.success(let third)), .some(let first), .some(let second), _, .some(let fourth)):
				queues.first.removeFirst()
				queues.second.removeFirst()
				queues.fourth.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .value((first, second, third, fourth), end: .complete)
				} else {
					return .value((first, second, third, fourth))
				}
			case (.result3(.success(let third)), _, _, _, _):
				queues.third.append(third)
				return .none
			case (.result3(.failure(let e)), _, _, _, _):
				if queues.third.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .end(e)
				} else {
					queues.thirdClosed = true
					return .none
				}
			case (.result4(.success(let fourth)), .some(let first), .some(let second), .some(let third), _):
				queues.first.removeFirst()
				queues.second.removeFirst()
				queues.third.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) {
					return .value((first, second, third, fourth), end: .complete)
				} else {
					return .value((first, second, third, fourth))
				}
			case (.result4(.success(let fourth)), _, _, _, _):
				queues.fourth.append(fourth)
				return .none
			case (.result4(.failure(let e)), _, _, _, _):
				if queues.fourth.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) {
					return .end(e)
				} else {
					queues.fourthClosed = true
					return .none
				}
			}
		}
	}
	
	@available(*, deprecated, message:"Renamed to zipWith. Alternately, use static zip function.")
	public func zip<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface>(_ second: U, _ third: V, _ fourth: W, _ fifth: X) -> Signal<(OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue)> {
		return zipWith(second, third, fourth, fifth)
	}
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameters:
	///   - second: another `Signal`
	///   - third: another `Signal`
	///   - fourth: another `Signal`
	///   - fifth: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `second`,`third`, `fourth` and `fifth`.
	public static func zip<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface>(_ first: Self, _ second: U, _ third: V, _ fourth: W, _ fifth: X) -> Signal<(Self.OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue)> {
		return first.zipWith(second, third, fourth, fifth)
	}
	
	/// Implementation of [Reactive X operator "zip"](http://reactivex.io/documentation/operators/zip.html)
	///
	/// - Parameters:
	///   - second: another `Signal`
	///   - third: another `Signal`
	///   - fourth: another `Signal`
	///   - fifth: another `Signal`
	/// - Returns: a signal that emits the values from `self`, paired with corresponding value from `second`,`third`, `fourth` and `fifth`.
	public func zipWith<U: SignalInterface, V: SignalInterface, W: SignalInterface, X: SignalInterface>(_ second: U, _ third: V, _ fourth: W, _ fifth: X) -> Signal<(OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue)> {
		return combine(second, third, fourth, fifth, initialState: (Array<OutputValue>(), Array<U.OutputValue>(), Array<V.OutputValue>(), Array<W.OutputValue>(), Array<X.OutputValue>(), false, false, false, false, false)) { (queues: inout (first: Array<OutputValue>, second: Array<U.OutputValue>, third: Array<V.OutputValue>, fourth: Array<W.OutputValue>, fifth: Array<X.OutputValue>, firstClosed: Bool, secondClosed: Bool, thirdClosed: Bool, fourthClosed: Bool, fifthClosed: Bool), r: EitherResult5<OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue>) -> Signal<(OutputValue, U.OutputValue, V.OutputValue, W.OutputValue, X.OutputValue)>.Next in
			switch (r, queues.first.first, queues.second.first, queues.third.first, queues.fourth.first, queues.fifth.first) {
			case (.result1(.success(let first)), _, .some(let second), .some(let third), .some(let fourth), .some(let fifth)):
				queues.second.removeFirst()
				queues.third.removeFirst()
				queues.fourth.removeFirst()
				queues.fifth.removeFirst()
				if (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .value((first, second, third, fourth, fifth), end: .complete)
				} else {
					return .value((first, second, third, fourth, fifth))
				}
			case (.result1(.success(let first)), _, _, _, _, _):
				queues.first.append(first)
				return .none
			case (.result1(.failure(let e)), _, _, _, _, _):
				if queues.first.isEmpty || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .end(e)
				} else {
					queues.firstClosed = true
					return .none
				}
			case (.result2(.success(let second)), .some(let first), _, .some(let third), .some(let fourth), .some(let fifth)):
				queues.first.removeFirst()
				queues.third.removeFirst()
				queues.fourth.removeFirst()
				queues.fifth.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .value((first, second, third, fourth, fifth), end: .complete)
				} else {
					return .value((first, second, third, fourth, fifth))
				}
			case (.result2(.success(let second)), _, _, _, _, _):
				queues.second.append(second)
				return .none
			case (.result2(.failure(let e)), _, _, _, _, _):
				if queues.second.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .end(e)
				} else {
					queues.secondClosed = true
					return .none
				}
			case (.result3(.success(let third)), .some(let first), .some(let second), _, .some(let fourth), .some(let fifth)):
				queues.first.removeFirst()
				queues.second.removeFirst()
				queues.fourth.removeFirst()
				queues.fifth.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.fourth.isEmpty && queues.fourthClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .value((first, second, third, fourth, fifth), end: .complete)
				} else {
					return .value((first, second, third, fourth, fifth))
				}
			case (.result3(.success(let third)), _, _, _, _, _):
				queues.third.append(third)
				return .none
			case (.result3(.failure(let e)), _, _, _, _, _):
				if queues.third.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.fourth.isEmpty && queues.fourthClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .end(e)
				} else {
					queues.thirdClosed = true
					return .none
				}
			case (.result4(.success(let fourth)), .some(let first), .some(let second), .some(let third), _, .some(let fifth)):
				queues.first.removeFirst()
				queues.second.removeFirst()
				queues.third.removeFirst()
				queues.fifth.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .value((first, second, third, fourth, fifth), end: .complete)
				} else {
					return .value((first, second, third, fourth, fifth))
				}
			case (.result4(.success(let fourth)), _, _, _, _, _):
				queues.fourth.append(fourth)
				return .none
			case (.result4(.failure(let e)), _, _, _, _, _):
				if queues.fourth.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fifth.isEmpty && queues.fifthClosed) {
					return .end(e)
				} else {
					queues.fourthClosed = true
					return .none
				}
			case (.result5(.success(let fifth)), .some(let first), .some(let second), .some(let third), .some(let fourth), _):
				queues.first.removeFirst()
				queues.second.removeFirst()
				queues.third.removeFirst()
				queues.fourth.removeFirst()
				if (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .value((first, second, third, fourth, fifth), end: .complete)
				} else {
					return .value((first, second, third, fourth, fifth))
				}
			case (.result5(.success(let fifth)), _, _, _, _, _):
				queues.fifth.append(fifth)
				return .none
			case (.result5(.failure(let e)), _, _, _, _, _):
				if queues.fifth.isEmpty || (queues.first.isEmpty && queues.firstClosed) || (queues.second.isEmpty && queues.secondClosed) || (queues.third.isEmpty && queues.thirdClosed) || (queues.fourth.isEmpty && queues.fourthClosed) {
					return .end(e)
				} else {
					queues.fifthClosed = true
					return .none
				}
			}
		}
	}
}

// Essentially a closure type used by `catchError`, defined as a separate class so the function can reference itself
fileprivate class CatchErrorRecovery<OutputValue> {
	let recover: (SignalEnd) -> Signal<OutputValue>
	let catchTypes: SignalEndPropagation
	init(recover: @escaping (SignalEnd) -> Signal<OutputValue>, catchTypes: SignalEndPropagation) {
		self.recover = recover
		self.catchTypes = catchTypes
	}
	func catchErrorRejoin(j: SignalJunction<OutputValue>, e: SignalEnd, i: SignalInput<OutputValue>) {
		if catchTypes.shouldPropagateEnd(e) {
			do {
				let f: SignalJunction<OutputValue>.Handler = self.catchErrorRejoin
				try recover(e).junction().bind(to: i, onEnd: f)
			} catch {
				i.send(end: .other(error))
			}
		} else {
			i.send(end: e)
		}
	}
}

// Essentially a closure type used by `retry`, defined as a separate class so the function can reference itself
fileprivate class RetryRecovery<U> {
	let shouldRetry: (inout U, SignalEnd) -> DispatchTimeInterval?
	let catchTypes: SignalEndPropagation
	var state: U
	let context: Exec
	var timer: Lifetime? = nil
	init(shouldRetry: @escaping (inout U, SignalEnd) -> DispatchTimeInterval?, catchTypes: SignalEndPropagation, state: U, context: Exec) {
		self.shouldRetry = shouldRetry
		self.catchTypes = catchTypes
		self.state = state
		self.context = context
	}
	func retryRejoin<OutputValue>(j: SignalJunction<OutputValue>, e: SignalEnd, i: SignalInput<OutputValue>) {
		if catchTypes.shouldPropagateEnd(e), let t = shouldRetry(&state, e) {
			timer = context.singleTimer(interval: t) {
				do {
					try j.bind(to: i, onEnd: self.retryRejoin)
				} catch {
					i.send(end: .other(error))
				}
			}
		} else {
			i.send(end: e)
		}
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "catch"](http://reactivex.io/documentation/operators/catch.html), returning a `Signal` on error in `self`.
	///
	/// - Parameters:
	///   - context: context where `recover` will run
	///   - catchSignalComplete: by default, the `recover` closure will be invoked only for unexpected errors, i.e. when `Error` is *not* a `SignalComplete`. Set this parameter to `true` to invoke the `recover` closure for *all* errors, including `SignalEnd.complete` and `SignalComplete.cancelled`. 
	///   - recover: a function that, when passed the `Error` that closed `self`, optionally returns a new signal.
	/// - Returns: a signal that emits the values from `self` until an error is received and then, if `recover` returns non-`nil` emits the values from `recover` and then emits the error from `recover`, otherwise if `recover` returns `nil`, emits the `Error` from `self`.
	public func catchError(context: Exec = .direct, catchSignalComplete: Bool = false, recover: @escaping (SignalEnd) -> Signal<OutputValue>) -> Signal<OutputValue> {
		let (input, sig) = Signal<OutputValue>.create()
		// Both `junction` and `input` are newly created so this can't be an error
		try! junction().bind(to: input, onEnd: CatchErrorRecovery(recover: recover, catchTypes: catchSignalComplete ? .all : .errors).catchErrorRejoin)
		return sig
	}
	
	/// Implementation of [Reactive X operator "retry"](http://reactivex.io/documentation/operators/retry.html) where the choice to retry and the delay between retries is controlled by a function.
	///
	/// - Note: a ReactiveX "resubscribe" is interpreted as a disconnect and reconnect, which will trigger reactivation iff (if and only if) the preceding nodes have behavior that supports that.
	///
	/// - Parameters:
	///   - initialState:  a mutable state value that will be passed into `shouldRetry`.
	///   - context: the `Exec` where timed reconnection will occcur (default: .global).
	///   - catchSignalComplete: by default, the `shouldRetry` closure will be invoked only for unexpected errors, i.e. when `Error` is *not* a `SignalComplete`. Set this parameter to `true` to invoke the `recover` closure for *all* errors, including `SignalEnd.complete` and `SignalComplete.cancelled`. 
	///   - shouldRetry: a function that, when passed the current state value and the `Error` that closed `self`, returns an `Optional<Double>`.
	/// - Returns: a signal that emits the values from `self` until an error is received and then, if `shouldRetry` returns non-`nil`, disconnects from `self`, delays by the number of seconds returned from `shouldRetry`, and reconnects to `self` (triggering re-activation), otherwise if `shouldRetry` returns `nil`, emits the `Error` from `self`. If the number of seconds is `0`, the reconnect is synchronous, otherwise it will occur in `context` using `invokeAsync`.
	public func retry<U>(_ initialState: U, context: Exec = .direct, catchSignalComplete: Bool = false, shouldRetry: @escaping (inout U, SignalEnd) -> DispatchTimeInterval?) -> Signal<OutputValue> {
		let (input, sig) = Signal<OutputValue>.create()
		// Both `junction` and `input` are newly created so this can't be an error
		try! junction().bind(to: input, onEnd: RetryRecovery(shouldRetry: shouldRetry, catchTypes: catchSignalComplete ? .all : .errors, state: initialState, context: context).retryRejoin)
		return sig
	}
	
	/// Implementation of [Reactive X operator "retry"](http://reactivex.io/documentation/operators/retry.html) where retries occur until the error is not `isSignalComplete` or `count` number of retries has occurred.
	///
	/// - Note: a ReactiveX "resubscribe" is interpreted as a disconnect and reconnect, which will trigger reactivation iff the preceding nodes have behavior that supports that.
	///
	/// - Parameters:
	///   - count: the maximum number of retries
	///   - delayInterval: the number of seconds between retries
	///   - context: the `Exec` where timed reconnection will occcur (default: .global).
	///   - catchSignalComplete: by default, retry attempts will occur only for unexpected errors, i.e. when `Error` is *not* a `SignalComplete`. Set this parameter to `true` to invoke the `recover` closure for *all* errors, including `SignalEnd.complete` and `SignalComplete.cancelled`. 
	/// - Returns: a signal that emits the values from `self` until an error is received and then, if fewer than `count` retries have occurred, disconnects from `self`, delays by `delaySeconds` and reconnects to `self` (triggering re-activation), otherwise if `count` retries have occurred, emits the `Error` from `self`. If the number of seconds is `0`, the reconnect is synchronous, otherwise it will occur in `context` using `invokeAsync`.
	public func retry(count: Int, delayInterval: DispatchTimeInterval, context: Exec = .direct, catchSignalComplete: Bool = false) -> Signal<OutputValue> {
		return retry(0, context: context) { (retryCount: inout Int, e: SignalEnd) -> DispatchTimeInterval? in
			if !catchSignalComplete && e.isComplete {
				return nil
			} else if retryCount < count {
				retryCount += 1
				return delayInterval
			} else {
				return nil
			}
		}
	}
	
	/// Implementation of [Reactive X operator "delay"](http://reactivex.io/documentation/operators/delay.html) where delay for each value is determined by running an `offset` function.
	///
	/// - Parameters:
	///   - initialState: a user state value passed into the `offset` function
	///   - closePropagation: determines how errors and closure in `offset` affects the resulting signal
	///   - context: the `Exec` where `offset` will run (default: .global).
	///   - offset: a function that, when passed the current state value and the latest value from `self`, returns the number of seconds that the value should be delayed (values less or equal to 0 are sent immediately).
	/// - Returns: a mirror of `self` where values are offset according to `offset` – closing occurs when `self` closes or when the last delayed value is sent (whichever occurs last).
	public func delay<U>(initialState: U, closePropagation: SignalEndPropagation = .none, context: Exec = .direct, offset: @escaping (inout U, OutputValue) -> DispatchTimeInterval) -> Signal<OutputValue> {
		return delay(initialState: initialState, closePropagation: closePropagation, context: context) { (state: inout U, value: OutputValue) -> Signal<Void> in
			return Signal<Void>.timer(interval: offset(&state, value), context: context)
		}
	}
	
	/// Implementation of [Reactive X operator "delay"](http://reactivex.io/documentation/operators/delay.html) where delay for each value is constant.
	///
	/// - Parameters:
	///   - interval: the delay for each value
	///   - context: the `Exec` where timed reconnection will occcur (default: .global).
	/// - Returns: a mirror of `self` where values are delayed by `seconds` – closing occurs when `self` closes or when the last delayed value is sent (whichever occurs last).
	public func delay(interval: DispatchTimeInterval, context: Exec = .direct) -> Signal<OutputValue> {
		return delay(initialState: interval, context: context) { (s: inout DispatchTimeInterval, v: OutputValue) -> DispatchTimeInterval in s }
	}
	
	/// Implementation of [Reactive X operator "delay"](http://reactivex.io/documentation/operators/delay.html) where delay for each value is determined by the duration of a signal returned from `offset`.
	///
	/// - Parameters:
	///   - closePropagation: determines how errors and closure in `offset` affects the resulting signal
	///   - context: the `Exec` where `offset` will run (default: .global).
	///   - offset: a function that, when passed the current state value emits a signal, the first value of which will trigger the end of the delay
	/// - Returns: a mirror of `self` where values are offset according to `offset` – closing occurs when `self` closes or when the last delayed value is sent (whichever occurs last).
	public func delay<U>(closePropagation: SignalEndPropagation = .none, context: Exec = .direct, offset: @escaping (OutputValue) -> Signal<U>) -> Signal<OutputValue> {
		return delay(initialState: (), closePropagation: closePropagation, context: context) { (state: inout (), value: OutputValue) -> Signal<U> in return offset(value) }
	}
	
	/// Implementation of [Reactive X operator "delay"](http://reactivex.io/documentation/operators/delay.html) where delay for each value is determined by the duration of a signal returned from `offset`.
	///
	/// - Parameters:
	///   - initialState: a user state value passed into the `offset` function
	///   - closePropagation: determines how errors and closure in `offset` affects the resulting signal
	///   - context: the `Exec` where `offset` will run (default: .global).
	///   - offset: a function that, when passed the current state value emits a signal, the first value of which will trigger the end of the delay
	/// - Returns: a mirror of `self` where values are offset according to `offset` – closing occurs when `self` closes or when the last delayed value is sent (whichever occurs last).
	public func delay<U, V>(initialState: V, closePropagation: SignalEndPropagation = .none, context: Exec = .direct, offset: @escaping (inout V, OutputValue) -> Signal<U>) -> Signal<OutputValue> {
		return valueDurations(initialState: initialState, closePropagation: closePropagation, context: context, offset).transform(initialState: [Int: OutputValue]()) { (values: inout [Int: OutputValue], r: Result<(Int, OutputValue?), SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let index, .some(let t)):
				values[index] = t
				return .none
			case .success(let index, .none):
				return values[index].map { .value($0) } ?? .none
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "do"](http://reactivex.io/documentation/operators/do.html) for "activation" (not a concept that directly exists in ReactiveX but similar to doOnSubscribe).
	///
	/// - Parameters:
	///   - context: where the handler will be invoked
	///   - handler: invoked when self is activated
	/// - Returns: a signal that emits the same outputs as self
	public func onActivate(context: Exec = .direct, _ handler: @escaping () -> ()) -> Signal<OutputValue> {
		let j = junction()
		let s = Signal<OutputValue>.generate { input in
			if let i = input {
				handler()
				_ = try? j.bind(to: i)
			} else {
				_ = j.disconnect()
			}
		}
		return s
	}
	
	/// Implementation of [Reactive X operator "do"](http://reactivex.io/documentation/operators/do.html) for "deactivation" (not a concept that directly exists in ReactiveX but similar to doOnUnsubscribe).
	///
	/// - Parameters:
	///   - context: where the handler will be invoked
	///   - handler: invoked when self is deactivated
	/// - Returns: a signal that emits the same outputs as self
	public func onDeactivate(context: Exec = .direct, _ handler: @escaping () -> ()) -> Signal<OutputValue> {
		let j = junction()
		let s = Signal<OutputValue>.generate { input in
			if let i = input {
				_ = try? j.bind(to: i)
			} else {
				handler()
				_ = j.disconnect()
			}
		}
		return s
	}
	
	/// Implementation of [Reactive X operator "do"](http://reactivex.io/documentation/operators/do.html) for "result" (equivalent to doOnEach).
	///
	/// - Parameters:
	///   - context: where the handler will be invoked
	///   - handler: invoked for each `Result` in the signal
	/// - Returns: a signal that emits the same outputs as self
	public func onResult(context: Exec = .direct, _ handler: @escaping (Result<OutputValue, SignalEnd>) -> ()) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			handler(r)
			return .single(r)
		}
	}
	
	/// Implementation of [Reactive X operator "do"](http://reactivex.io/documentation/operators/do.html) for "values" (equivalent to doOnNext).
	///
	/// - Parameters:
	///   - context: where the handler will be invoked
	///   - handler: invoked for each value (Result.success) in the signal
	/// - Returns: a signal that emits the same outputs as self
	public func onValue(context: Exec = .direct, _ handler: @escaping (OutputValue) -> ()) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				handler(v)
				return .value(v)
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "do"](http://reactivex.io/documentation/operators/do.html) for "errors" (equivalent to doOnTerminate).
	///
	/// - Parameters:
	///   - context: where the handler will be invoked
	///   - handler: invoked for each error (Result.failure) in the signal
	/// - Returns: a signal that emits the same outputs as self
	public func onError(context: Exec = .direct, catchSignalComplete: Bool = false, _ handler: @escaping (SignalEnd) -> ()) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				return .value(v)
			case .failure(let e):
				if catchSignalComplete || !e.isComplete {
					handler(e)
				}
				return .end(e)
			}
		}
	}
	
	/// Appends an onActivate, onValue, onError and onDeactivate operator to monitor behavior and inspect lifecycle events.
	///
	/// - Parameters:
	///   - logPrefix: Prepended to the front of log statements. If non-empty, ": " is *also* prepended.
	///   - file: suffixed to the log statement (defaults to #file)
	///   - line: suffixed to the log statement (defaults to #line)
	/// - Returns: the otherwise untransformed signal
	public func debug(logPrefix: String = "", file: String = #file, line: Int = #line) -> Signal<OutputValue> {
		let prefix = logPrefix + (logPrefix.isEmpty ? "" : ": ")
		return onActivate { print("\(prefix)Activated at   \(file):\(line)") }
			.onValue { print("\(prefix)Value at       \(file):\(line) - \($0)") }
			.onError { print("\(prefix)Error at       \(file):\(line) - \($0)") }
			.onDeactivate { print("\(prefix)Deactivated at \(file):\(line)") }
	}
	
	/// Implementation of [Reactive X operator "materialize"](http://reactivex.io/documentation/operators/materialize-dematerialize.html)
	///
	/// WARNING: in CwlSignal, this operator will emit a `SignalEnd.complete` into the output signal immediately after emitting the first wrapped error. Within the "first error closes signal" behavior of CwlSignal, this is the only behavior that makes sense (since no further upstream values will be received), however, it does limit the usefulness of `materialize` to constructions where the `materialize` signal immediately outputs into a `SignalMultiInput` (including abstractions built on top, like `switchLatest` or child signals of a `flatMap`) that ignore non-error close conditions from the source signal.
	///
	/// - Returns: a signal where each `Result` emitted from self is further wrapped in a Result.success.
	public func materialize() -> Signal<Result<OutputValue, SignalEnd>> {
		return transform { r in
			if r.isFailure {
				return .value(r, end: .complete)
			} else {
				return .value(r)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "dematerialize"](http://reactivex.io/documentation/operators/materialize-dematerialize.html)
	///
	/// NOTE: ideally, this would not be a static function but a "same type" conditional extension. In a future Swift release this will probably change.
	///
	/// - Parameter signal: a signal whose OutputValue is a `Result` wrapped version of an underlying type
	/// - Returns: a signal whose OutputValue is the unwrapped value from the input, with unwrapped errors sent as errors.
	public static func dematerialize<OutputValue>(_ signal: Signal<Result<OutputValue, SignalEnd>>) -> Signal<OutputValue> {
		return signal.transform { (r: Result<Result<OutputValue, SignalEnd>, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(.success(let v)): return .value(v)
			case .success(.failure(let e)): return .end(e)
			case .failure(let e): return .end(e)
			}
		}
	}
}

extension SignalInterface {
	/// - Note: the [Reactive X operator "ObserveOn"](http://reactivex.io/documentation/operators/observeon.html) doesn't apply to CwlSignal.Signal since any CwlSignal.Signal that runs work can specify their own execution context and control scheduling in that way.
	
	/// - Note: the [Reactive X operator "Serialize"](http://reactivex.io/documentation/operators/serialize.html) doesn't apply to CwlSignal.Signal since all CwlSignal.Signal instances are always serialized and well-behaved under multi-threaded access.
	
	/// - Note: the [Reactive X operator "Subscribe" and "SubscribeOn"](http://reactivex.io/documentation/operators/subscribe.html) are implemented as `subscribe`.
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "TimeInterval"](http://reactivex.io/documentation/operators/timeinterval.html)
	///
	/// - Parameter context: time between emissions will be calculated based on the timestamps from this context
	/// - Returns: a signal where the values are seconds between emissions from self
	public func timeInterval(context: Exec = .direct) -> Signal<Double> {
		let junction = self.map { v in () }.junction()
		
		// This `generate` transform is used to capture the start of the stream
		let s = Signal<Void>.generate { input in
			if let i = input {
				i.send(value: ())
				
				// Then after sending the initial value, connect to upstream
				try! junction.bind(to: i)
			} else {
				_ = junction.disconnect()
			}
		}.transform(initialState: nil, context: context) { (lastTime: inout DispatchTime?, r: Result<Void, SignalEnd>) -> Signal<Double>.Next in
			switch r {
			case .success:
				let currentTime = context.timestamp()
				if let l = lastTime {
					lastTime = currentTime
					return .value(currentTime.since(l).seconds)
				} else {
					lastTime = currentTime
					return .none
				}
			case .failure(let e):
				return .end(e)
			}
		}
		return s
	}
	
	/// Implementation of [Reactive X operator "Timeout"](http://reactivex.io/documentation/operators/timeout.html)
	///
	/// - Parameters:
	///   - interval: the duration before a SignalReactiveError.timeout will be emitted
	///   - resetOnValue: if `true`, each value sent through the signal will reset the timer (making the timeout an "idle" timeout). If `false`, the timeout duration is measured from the start of the signal and is unaffected by whether values are received.
	///   - context: timestamps will be added based on the time in this context
	/// - Returns: a mirror of self unless a timeout occurs, in which case it will closed by a SignalReactiveError.timeout
	public func timeout(interval: DispatchTimeInterval, resetOnValue: Bool = true, context: Exec = .direct) -> Signal<OutputValue> {
		let (input, s) = Signal<Void>.create()
		let junction = Signal<Void>.timer(interval: interval, context: context).junction()
		// Both `junction` and `input` are newly created so this can't be an error
		try! junction.bind(to: input)
		return combine(s, context: context) { (cr: EitherResult2<OutputValue, ()>) -> Signal<OutputValue>.Next in
			switch cr {
			case .result1(let r):
				if resetOnValue {
					junction.rebind()
				}
				return .single(r)
			case .result2:
				return .end(.other(SignalReactiveError.timeout))
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Timestamp"](http://reactivex.io/documentation/operators/timestamp.html)
	///
	/// - Parameter context: used as the source of time
	/// - Returns: a signal where the values are a two element tuple, first element is self.OutputValue, second element is the `DispatchTime` timestamp that this element was emitted from self.
	public func timestamp(context: Exec = .direct) -> Signal<(OutputValue, DispatchTime)> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<(OutputValue, DispatchTime)>.Next in
			switch r {
			case .success(let v): return .value((v, context.timestamp()))
			case .failure(let e): return .end(e)
			}
		}
	}
}

extension SignalInterface {
	/// - Note: the [Reactive X operator "Using"](http://reactivex.io/documentation/operators/using.html) doesn't apply to CwlSignal.Signal which uses standard Swift reference counted lifetimes. Resources should be captured by closures or `transform(initialState:...)`.
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "All"](http://reactivex.io/documentation/operators/all.html)
	///
	/// - Parameters:
	///   - context: the `test` function will be run in this context
	///   - test: will be invoked for every value
	/// - Returns: a signal that emits true and then closes if every value emitted by self returned true from the `test` function and self closed normally, otherwise emits false and then closes
	public func all(context: Exec = .direct, test: @escaping (OutputValue) -> Bool) -> Signal<Bool> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<Bool>.Next in
			switch r {
			case .success(let v) where !test(v): return .value(false, end: .complete)
			case .failure(.complete): return .value(true, end: .complete)
			case .failure(let e): return .end(e)
			case .success: return .none
			}
		}
	}
}

extension Signal {
	/// Implementation of [Reactive X operator "Amb"](http://reactivex.io/documentation/operators/amb.html) using the alternate name `race`, since it better conveys the purpose.
	///
	/// - Parameter inputs: a set of inputs
	/// - Returns: connects to all inputs then emits the full set of values from the first of these to emit a value
	public static func race<S: Sequence>(sequence: S) -> Signal<OutputValue> where S.Iterator.Element == Signal<OutputValue> {
		let (mergedInput, sig) = Signal<(Int, Result)>.createMergedInput()
		sequence.enumerated().forEach { s in
			mergedInput.add(s.element.transform { r in
				return .value((s.offset, r))
			}, closePropagation: .errors)
		}
		return sig.transform(initialState: -1) { (first: inout Int, r: Signal<(Int, Result)>.Result) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let index, let underlying) where first < 0:
				first = index
				return .single(underlying)
			case .success(let index, let underlying) where first < 0 || first == index:
				return .single(underlying)
			case .failure(let e):
				return .end(e)
			case .success:
				return .none
			}
		}
	}

	public static func race(_ signals: Signal<OutputValue>...) -> Signal<OutputValue> {
		return race(sequence: signals)
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "Some"](http://reactivex.io/documentation/operators/some.html)
	///
	/// - Parameters:
	///   - context: the `test` function will be run in this context
	///   - test: will be invoked for every value
	/// - Returns: a signal that emits true and then closes when a value emitted by self returns true from the `test` function, otherwise if no values from self return true, emits false and then closes
	public func find(context: Exec = .direct, test: @escaping (OutputValue) -> Bool) -> Signal<Bool> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<Bool>.Next in
			switch r {
			case .success(let v) where test(v):
				return .value(true, end: .complete)
			case .success:
				return .none
			case .failure(let e):
				return .value(false, end: e)
			}
		}
	}

	/// Implementation of [Reactive X operator "Some"](http://reactivex.io/documentation/operators/some.html)
	///
	/// - Parameters:
	///   - context: the `test` function will be run in this context
	///   - test: will be invoked for every value
	/// - Returns: a signal that emits true and then closes when a value emitted by self returns true from the `test` function, otherwise if no values from self return true, emits false and then closes
	public func findIndex(context: Exec = .direct, test: @escaping (OutputValue) -> Bool) -> Signal<Int?> {
		return transform(initialState: 0, context: context) { (index: inout Int, r: Result<OutputValue, SignalEnd>) -> Signal<Int?>.Next in
			switch r {
			case .success(let v) where test(v):
				return .value(index, end: .complete)
			case .success:
				index += 1
				return .none
			case .failure(let e):
				return .value(nil, end: e)
			}
		}
	}
}

extension SignalInterface where OutputValue: Equatable {
	/// Implementation of [Reactive X operator "Some"](http://reactivex.io/documentation/operators/some.html)
	///
	/// - Parameter value: every value emitted by self is tested for equality with this value
	/// - Returns: a signal that emits true and then closes when a value emitted by self tests as `==` to `value`, otherwise if no values from self test as equal, emits false and then closes
	public func find(value: OutputValue) -> Signal<Bool> {
		return find { value == $0 }
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "DefaultIfEmpty"](http://reactivex.io/documentation/operators/defaultifempty.html)
	///
	/// - Parameter value: value to emit if self closes without a value
	/// - Returns: a signal that emits the same values as self or `value` if self closes without emitting a value
	public func defaultIfEmpty(value: OutputValue) -> Signal<OutputValue> {
		return transform(initialState: false) { (started: inout Bool, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			switch r {
			case .success(let v):
				started = true
				return .value(v)
			case .failure(let e) where !started:
				return .value(value, end: e)
			case .failure(let e):
				return .end(e)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "SwitchIfEmpty"](http://reactivex.io/documentation/operators/switchifempty.html)
	///
	/// - Parameter alternate: content will be used if self closes without emitting a value
	/// - Returns: a signal that emits the same values as self or mirrors `alternate` if self closes without emitting a value
	public func switchIfEmpty(alternate: Signal<OutputValue>) -> Signal<OutputValue> {
		var fallback: Signal<OutputValue>? = alternate
		let (input, preMappedSignal) = Signal<OutputValue>.create()
		let s = preMappedSignal.map { (t: OutputValue) -> OutputValue in
			fallback = nil
			return t
		}
		
		// Both `junction` and `input` are newly created so this can't be an error
		try! junction().bind(to: input) { (j: SignalJunction<OutputValue>, e: SignalEnd, i: SignalInput<OutputValue>) in
			if let f = fallback {
				f.bind(to: i)
			} else {
				i.send(end: e)
			}
		}
		return s
	}
}

extension SignalInterface where OutputValue: Equatable {
	/// Implementation of [Reactive X operator "SequenceEqual"](http://reactivex.io/documentation/operators/sequenceequal.html)
	///
	/// - Parameter to: another signal whose contents will be compared to this signal
	/// - Returns: a signal that emits `true` if `self` and `to` are equal, `false` otherwise
	public func sequenceEqual(to: Signal<OutputValue>) -> Signal<Bool> {
		return combine(to, initialState: (Array<OutputValue>(), Array<OutputValue>(), false, false)) { (state: inout (lq: Array<OutputValue>, rq: Array<OutputValue>, lc: Bool, rc: Bool), r: EitherResult2<OutputValue, OutputValue>) -> Signal<Bool>.Next in
			// state consists of lq (left queue), rq (right queue), lc (left closed), rc (right closed)
			switch (r, state.lq.first, state.rq.first) {
			case (.result1(.success(let left)), _, .some(let right)):
				if left != right {
					return .value(false, end: .complete)
				}
				state.rq.removeFirst()
				return .none
			case (.result1(.success(let left)), _, _):
				state.lq.append(left)
				return .none
			case (.result2(.success(let right)), .some(let left), _):
				if left != right {
					return .value(false, end: .complete)
				}
				state.lq.removeFirst()
				return .none
			case (.result2(.success(let right)), _, _):
				state.rq.append(right)
				return .none
			case (.result1(.failure(let e)), _, _):
				state.lc = true
				if state.rc {
					if state.lq.count == state.rq.count {
						return .value(true, end: e)
					} else {
						return .value(false, end: e)
					}
				}
				return .none
			case (.result2(.failure(let e)), _, _):
				state.rc = true
				if state.lc {
					if state.lq.count == state.rq.count {
						return .value(true, end: e)
					} else {
						return .value(false, end: e)
					}
				}
				return .none
			}
		}
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "SkipUntil"](http://reactivex.io/documentation/operators/skipuntil.html)
	///
	/// - Parameter other: until this signal emits a value, all values from self will be dropped
	/// - Returns: a signal that mirrors `self` after `other` emits a value (but won't emit anything prior)
	public func skipUntil<U: SignalInterface>(_ other: U) -> Signal<OutputValue> {
		return combine(other, initialState: false) { (started: inout Bool, cr: EitherResult2<OutputValue, U.OutputValue>) -> Signal<OutputValue>.Next in
			switch cr {
			case .result1(.success(let v)) where started:
				return .value(v)
			case .result1(.success):
				return .none
			case .result1(.failure(let e)):
				return .end(e)
			case .result2(.success):
				started = true
				return .none
			case .result2(.failure):
				return .none
			}
		}
	}
	
	/// Implementation of [Reactive X operator "SkipWhile"](http://reactivex.io/documentation/operators/skipwhile.html)
	///
	/// - Parameters:
	///   - context: execution context where `condition` will be run
	///   - condition: will be run for every value emitted from `self` until `condition` returns `true`
	/// - Returns: a signal that mirrors `self` dropping values until `condition` returns `true` for one of the values
	public func skipWhile(context: Exec = .direct, condition: @escaping (OutputValue) throws -> Bool) -> Signal<OutputValue> {
		return transform(initialState: false, context: context) { (started: inout Bool, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try !started && condition(v):
					return .none
				case .success(let v):
					started = true
					return .value(v)
				case .failure(let e):
					return .end(e)
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "SkipWhile"](http://reactivex.io/documentation/operators/skipwhile.html)
	///
	/// - Parameters:
	///   - initialState: intial value for a state parameter that will be passed to `condition` on each invocation
	///   - context: execution context where `condition` will be run
	///   - condition: will be run for every value emitted from `self` until `condition` returns `true`
	/// - Returns: a signal that mirrors `self` dropping values until `condition` returns `true` for one of the values
	public func skipWhile<U>(initialState initial: U, context: Exec = .direct, condition: @escaping (inout U, OutputValue) throws -> Bool) -> Signal<OutputValue> {
		return transform(initialState: (initial, false), context: context) { (started: inout (U, Bool), r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try !started.1 && condition(&started.0, v):
					return .none
				case .success(let v):
					started.1 = true
					return .value(v)
				case .failure(let e):
					return .end(e)
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "TakeUntil"](http://reactivex.io/documentation/operators/takeuntil.html)
	///
	/// - Parameter other: after this signal emits a value, all values from self will be dropped
	/// - Returns: a signal that mirrors `self` until `other` emits a value (but won't emit anything after)
	public func takeUntil<U: SignalInterface>(_ other: U) -> Signal<OutputValue> {
		return combine(other, initialState: false) { (started: inout Bool, cr: EitherResult2<OutputValue, U.OutputValue>) -> Signal<OutputValue>.Next in
			switch cr {
			case .result1(.success(let v)) where !started: return .value(v)
			case .result1(.success): return .none
			case .result1(.failure(let e)): return .end(e)
			case .result2(.success):
				started = true
				return .none
			case .result2(.failure): return .none
			}
		}
	}
	
	/// Implementation of [Reactive X operator "TakeWhile"](http://reactivex.io/documentation/operators/takewhile.html)
	///
	/// - Parameters:
	///   - context: execution context where `condition` will be run
	///   - condition: will be run for every value emitted from `self` until `condition` returns `true`
	/// - Returns: a signal that mirrors `self` dropping values after `condition` returns `true` for one of the values
	public func takeWhile(context: Exec = .direct, condition: @escaping (OutputValue) throws -> Bool) -> Signal<OutputValue> {
		return transform(context: context) { (r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try condition(v): return .value(v)
				case .success: return .complete()
				case .failure(let e): return .end(e)
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "TakeWhile"](http://reactivex.io/documentation/operators/takewhile.html)
	///
	/// - Parameters:
	///   - initialState: intial value for a state parameter that will be passed to `condition` on each invocation
	///   - context: execution context where `condition` will be run
	///   - condition: will be run for every value emitted from `self` until `condition` returns `true`
	/// - Returns: a signal that mirrors `self` dropping values after `condition` returns `true` for one of the values
	public func takeWhile<U>(initialState initial: U, context: Exec = .direct, condition: @escaping (inout U, OutputValue) throws -> Bool) -> Signal<OutputValue> {
		return transform(initialState: initial, context: context) { (i: inout U, r: Result<OutputValue, SignalEnd>) -> Signal<OutputValue>.Next in
			do {
				switch r {
				case .success(let v) where try condition(&i, v): return .value(v)
				case .success: return .complete()
				case .failure(let e): return .end(e)
				}
			} catch {
				return .error(error)
			}
		}
	}
	
	/// A helper method used for mathematical operators. Performs a basic `fold` over the values emitted by `self` then passes the final result through another `finalize` function before emitting the result as a value in the returned signal.
	///
	/// - Parameters:
	///   - initial: used to initialize the fold state
	///   - context: all functions will be invoked in this context
	///   - finalize: invoked when `self` closes, with the current fold state value
	///   - fold: invoked for each value emitted by `self` along with the current fold state value
	/// - Returns: a signal which emits the `finalize` result
	public func foldAndFinalize<U, V>(_ initial: V, context: Exec = .direct, finalize: @escaping (V) throws -> U?, fold: @escaping (V, OutputValue) throws -> V) -> Signal<U> {
		return transform(initialState: initial, context: context) { (state: inout V, r: Result<OutputValue, SignalEnd>) -> Signal<U>.Next in
			do {
				switch r {
				case .success(let v):
					state = try fold(state, v)
					return .none
				case .failure(let e):
					if let v = try finalize(state) {
						return .value(v, end: e)
					} else {
						return .end(e)
					}
				}
			} catch {
				return .error(error)
			}
		}
	}
}

extension SignalInterface where OutputValue: BinaryInteger {
	/// Implementation of [Reactive X operator "Average"](http://reactivex.io/documentation/operators/average.html)
	///
	/// - Returns: a signal that emits a single value... the sum of all values emitted by `self`
	public func average() -> Signal<OutputValue> {
		return foldAndFinalize((0, 0), finalize: { (fold: (OutputValue, OutputValue)) -> OutputValue? in fold.0 > 0 ? fold.1 / fold.0 : nil }) { (fold: (OutputValue, OutputValue), value: OutputValue) -> (OutputValue, OutputValue) in
			return (fold.0 + 1, fold.1 + value)
		}
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "Concat"](http://reactivex.io/documentation/operators/concat.html)
	///
	/// - Parameter other: a second signal
	/// - Returns: a signal that emits all the values from `self` followed by all the values from `other` (including those emitted while `self` was still active)
	public func concat(_ other: Signal<OutputValue>) -> Signal<OutputValue> {
		return combine(other, initialState: ([OutputValue](), nil, nil)) { (state: inout (secondValues: [OutputValue], firstError: SignalEnd?, secondError: SignalEnd?), cr: EitherResult2<OutputValue, OutputValue>) -> Signal<OutputValue>.Next in
			switch (cr, state.firstError) {
			case (.result1(.success(let v)), _):
				return .value(v)
			case (.result1(.failure(.complete)), _):
				if let e2 = state.secondError {
					return .values(sequence: state.secondValues, end: e2)
				} else {
					state.firstError = .complete
					return .values(sequence: state.secondValues)
				}
			case (.result1(.failure(let e1)), _):
				// In the event of an "unexpected" error, don't emit the second signal.
				return .end(e1)
			case (.result2(.success(let v)), .none):
				state.secondValues.append(v)
				return .none
			case (.result2(.success(let v)), .some):
				return .value(v)
			case (.result2(.failure(let e2)), .none):
				state.secondError = e2
				return .none
			case (.result2(.failure(let e2)), .some):
				return .end(e2)
			}
		}
	}
	
	/// Implementation of [Reactive X operator "Count"](http://reactivex.io/documentation/operators/count.html)
	///
	/// - Returns: a signal that emits the number of values emitted by `self`
	public func count() -> Signal<Int> {
		return aggregate(0) { (fold: (Int), value: OutputValue) -> Int in
			return fold + 1
		}
	}
}

extension SignalInterface where OutputValue: Comparable {
	/// Implementation of [Reactive X operator "Min"](http://reactivex.io/documentation/operators/min.html)
	///
	/// - Returns: the smallest value emitted by self
	public func min() -> Signal<OutputValue> {
		return foldAndFinalize(nil, finalize: { $0 }) { (fold: OutputValue?, value: OutputValue) -> OutputValue? in
			return fold.map { value < $0 ? value : $0 } ?? value
		}
	}
	
	/// Implementation of [Reactive X operator "Max"](http://reactivex.io/documentation/operators/max.html)
	///
	/// - Returns: the largest value emitted by self
	public func max() -> Signal<OutputValue> {
		return foldAndFinalize(nil, finalize: { $0 }) { (fold: OutputValue?, value: OutputValue) -> OutputValue? in
			return fold.map { value > $0 ? value : $0 } ?? value
		}
	}
}

extension SignalInterface {
	/// Implementation of [Reactive X operator "Reduce"](http://reactivex.io/documentation/operators/reduce.html). The .NET/alternate name of `aggregate` is used to avoid conflict with the Signal.reduce function.
	///
	/// See also: `scan` which applies the same logic but emits the `fold` value on *every* invocation.
	///
	/// - Parameters:
	///   - initial: initialize the state value
	///   - context: the `fold` function will be invoked on this context
	///   - fold: invoked for every value emitted from self
	/// - Returns: emits the last emitted `fold` state value
	public func aggregate<U>(_ initial: U, context: Exec = .direct, fold: @escaping (U, OutputValue) -> U) -> Signal<U> {
		return foldAndFinalize(initial, context: context, finalize: { $0 }) { (state: U, value: OutputValue) in
			return fold(state, value)
		}
	}
}

extension SignalInterface where OutputValue: Numeric {
	/// Implementation of [Reactive X operator "Sum"](http://reactivex.io/documentation/operators/sum.html)
	///
	/// - Returns: a signal that emits the sum of all values emitted by self
	public func sum() -> Signal<OutputValue> {
		return aggregate(0) { (fold: OutputValue, value: OutputValue) -> OutputValue in
			return fold + value
		}
	}
}
