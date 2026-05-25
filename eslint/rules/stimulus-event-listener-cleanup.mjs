// Enforces the Stimulus controller event-listener-cleanup discipline documented
// in CLAUDE.md: any addEventListener inside a Stimulus controller must use a
// stored bound reference (e.g. `this.boundFoo`) so that disconnect() can pass
// the same function to removeEventListener.

const inlineHandlerMessage =
  "addEventListener handler must be a stored reference (e.g. `this.boundFoo` assigned in connect()) — inline arrows, function expressions, and `.bind(this)` calls each produce a fresh function that removeEventListener cannot match."

const missingDisconnectMessage =
  "Stimulus controller calls addEventListener but does not define a disconnect() method to clean up listeners."

function isStimulusController(node) {
  const sc = node.superClass
  return sc && sc.type === "Identifier" && sc.name === "Controller"
}

function hasDisconnectMethod(classNode) {
  return classNode.body.body.some(
    (m) =>
      m.type === "MethodDefinition" &&
      !m.static &&
      m.key.type === "Identifier" &&
      m.key.name === "disconnect"
  )
}

function isAcceptableHandler(arg) {
  // Stored reference: this.boundFoo, this.handlers.foo, someVar, fn.someMethod
  if (arg.type === "Identifier") return true
  if (arg.type === "MemberExpression") return true
  return false
}

export default {
  meta: {
    type: "problem",
    docs: {
      description:
        "Require Stimulus controllers to use stored event-listener references and define disconnect() for cleanup.",
    },
    schema: [],
    messages: {
      inlineHandler: inlineHandlerMessage,
      missingDisconnect: missingDisconnectMessage,
    },
  },
  create(context) {
    const classStack = []

    function currentControllerClass() {
      for (let i = classStack.length - 1; i >= 0; i--) {
        if (classStack[i].isStimulus) return classStack[i].node
      }
      return null
    }

    function enterClass(node) {
      classStack.push({ node, isStimulus: isStimulusController(node) })
    }

    function exitClass() {
      classStack.pop()
    }

    return {
      ClassDeclaration: enterClass,
      "ClassDeclaration:exit": exitClass,
      ClassExpression: enterClass,
      "ClassExpression:exit": exitClass,

      CallExpression(node) {
        const controllerClass = currentControllerClass()
        if (!controllerClass) return

        const callee = node.callee
        if (callee.type !== "MemberExpression") return
        if (callee.computed) return
        if (callee.property.type !== "Identifier") return
        if (callee.property.name !== "addEventListener") return
        if (node.arguments.length < 2) return

        const handler = node.arguments[1]

        if (!isAcceptableHandler(handler)) {
          context.report({ node: handler, messageId: "inlineHandler" })
        }

        if (!hasDisconnectMethod(controllerClass)) {
          context.report({ node, messageId: "missingDisconnect" })
        }
      },
    }
  },
}
