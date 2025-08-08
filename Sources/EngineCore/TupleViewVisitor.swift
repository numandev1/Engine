//
// Copyright (c) Nathan Tannar
//

import SwiftUI

extension TupleView: MultiView {
    public nonisolated func makeSubviewIterator() -> some MultiViewIterator {
        SafeTupleSubviewIterator(tupleView: self)
    }
}

private struct SafeTupleSubviewIterator<Content>: MultiViewIterator {
    let tupleView: TupleView<Content>
    
    init(tupleView: TupleView<Content>) {
        self.tupleView = tupleView
    }
    
    func visit<Visitor: MultiViewVisitor>(
        visitor: UnsafeMutablePointer<Visitor>,
        context: Context,
        stop: inout Bool
    ) {
        let content = try! swift_getFieldValue("value", Content.self, tupleView)
        
        let iterator = TupleSubviewIterator(content: content)
        iterator.visit(visitor: visitor, context: context, stop: &stop)
    }
}

private struct TupleSubviewIterator<
    Content
>: MultiViewIterator {

    var content: Content

    init(content: Content) {
        self.content = content
    }

    func visit<
        Visitor: MultiViewVisitor
    >(
        visitor: UnsafeMutablePointer<Visitor>,
        context: Context,
        stop: inout Bool
    ) {
        if context.traits.contains(.header) || context.traits.contains(.footer) {
            visitor.value.visit(
                content: TupleView(content),
                context: context,
                stop: &stop
            )
        } else {
            if let tuple = Tuple(content) {
                var vistor = TupleSubviewIteratorElementVisitor(
                    visitor: visitor,
                    context: context
                )
                tuple.visit(visitor: &vistor, stop: &stop)
            } else if let conformance = ViewProtocolDescriptor.conformance(of: Content.self) {
                var visitor = TupleSubviewIteratorViewVisitor(
                    element: content,
                    visitor: visitor,
                    context: context
                )
                conformance.visit(visitor: &visitor)
            } else {
                visitor.value.visit(
                    content: TupleView(content),
                    context: context,
                    stop: &stop
                )
            }
        }
    }
}

private struct TupleSubviewIteratorElementVisitor<
    Visitor: MultiViewVisitor
>: TupleVisitor {

    var visitor: UnsafeMutablePointer<Visitor>
    var context: MultiViewIteratorContext
    var index = 0

    mutating func visit<Element>(
        element: Element,
        offset: Offset,
        stop: inout Bool
    ) {
        if let conformance = ViewProtocolDescriptor.conformance(of: Element.self) {
            var context = context
            context.id.append(offset: index)
            var visitor = TupleSubviewIteratorViewVisitor(
                element: element,
                visitor: visitor,
                context: context
            )
            conformance.visit(visitor: &visitor)
            stop = visitor.stop
        }
        index += 1
    }
}

private struct TupleSubviewIteratorViewVisitor<
    Element,
    Visitor: MultiViewVisitor
>: ViewVisitor {

    var element: Element
    var visitor: UnsafeMutablePointer<Visitor>
    var context: MultiViewIteratorContext
    var stop = false

    mutating func visit<Content: View>(type: Content.Type) {
        let content = unsafeBitCast(element, to: Content.self)
        var context = context
        context.id.append(Content.self)
        content.visit(visitor: visitor, context: context, stop: &stop)
    }
}
