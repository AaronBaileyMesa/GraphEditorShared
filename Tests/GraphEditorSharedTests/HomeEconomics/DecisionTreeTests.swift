//
//  DecisionTreeTests.swift
//  GraphEditorSharedTests
//
//  Tests for decision tree operations
//

import XCTest
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
final class DecisionTreeTests: XCTestCase {
    
    var model: GraphModel!
    
    @MainActor
    override func setUp() async throws {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        model = GraphModel(storage: storage, physicsEngine: physicsEngine)
    }
    
    // MARK: - Person Node Tests
    
    @MainActor
    func testAddPerson() async throws {
        let person = await model.addPerson(
            name: "Dad",
            defaultSpiceLevel: "hot",
            dietaryRestrictions: ["gluten-free"],
            at: CGPoint(x: 100, y: 100)
        )
        
        XCTAssertEqual(person.name, "Dad")
        XCTAssertEqual(person.defaultSpiceLevel, "hot")
        XCTAssertEqual(person.dietaryRestrictions, ["gluten-free"])
        XCTAssertEqual(model.nodes.count, 1)
    }
    
    // MARK: - Decision Node Tests
    
    @MainActor
    func testAddDecision() async throws {
        let decision = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        XCTAssertEqual(decision.question, "What protein?")
        XCTAssertEqual(decision.preferenceKey, "protein")
        XCTAssertEqual(decision.inputType, .singleChoice)
        XCTAssertEqual(model.nodes.count, 1)
    }
    
    @MainActor
    func testAddChoiceToDecision() async throws {
        let decision = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        let choice = await model.addChoice(
            to: decision.id,
            choiceText: "Beef",
            value: .string("beef"),
            at: CGPoint(x: 150, y: 150)
        )
        
        XCTAssertNotNil(choice)
        XCTAssertEqual(choice?.choiceText, "Beef")
        XCTAssertEqual(model.nodes.count, 2)
        
        // Verify choice is child of decision
        let updatedDecision = model.nodes.first(where: { $0.id == decision.id })?.unwrapped as? DecisionNode
        XCTAssertNotNil(updatedDecision)
        XCTAssertTrue(updatedDecision!.children.contains(choice!.id))
    }
    
    // MARK: - Choice Selection Tests
    
    @MainActor
    func testSelectSingleChoice() async throws {
        let decision = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        let beef = await model.addChoice(
            to: decision.id,
            choiceText: "Beef",
            value: .string("beef"),
            at: CGPoint(x: 150, y: 150)
        )!
        
        let chicken = await model.addChoice(
            to: decision.id,
            choiceText: "Chicken",
            value: .string("chicken"),
            at: CGPoint(x: 200, y: 150)
        )!
        
        // Select beef
        let success = await model.selectChoice(beef.id, in: decision.id)
        XCTAssertTrue(success)
        
        // Verify beef is selected
        let beefNode = model.nodes.first(where: { $0.id == beef.id })?.unwrapped as? ChoiceNode
        XCTAssertTrue(beefNode!.isSelected)
        
        // Verify chicken is not selected
        let chickenNode = model.nodes.first(where: { $0.id == chicken.id })?.unwrapped as? ChoiceNode
        XCTAssertFalse(chickenNode!.isSelected)
    }
    
    @MainActor
    func testSelectMultipleChoices() async throws {
        let decision = await model.addDecision(
            question: "What toppings?",
            preferenceKey: "toppings",
            inputType: .multiChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        let lettuce = await model.addChoice(
            to: decision.id,
            choiceText: "Lettuce",
            value: .string("lettuce"),
            at: CGPoint(x: 150, y: 150)
        )!
        
        let tomato = await model.addChoice(
            to: decision.id,
            choiceText: "Tomato",
            value: .string("tomato"),
            at: CGPoint(x: 200, y: 150)
        )!
        
        // Select both
        _ = await model.selectChoice(lettuce.id, in: decision.id)
        _ = await model.selectChoice(tomato.id, in: decision.id)
        
        // Verify both are selected
        let lettuceNode = model.nodes.first(where: { $0.id == lettuce.id })?.unwrapped as? ChoiceNode
        let tomatoNode = model.nodes.first(where: { $0.id == tomato.id })?.unwrapped as? ChoiceNode
        
        XCTAssertTrue(lettuceNode!.isSelected)
        XCTAssertTrue(tomatoNode!.isSelected)
    }
    
    @MainActor
    func testSetNumericValue() async throws {
        let decision = await model.addDecision(
            question: "How many guests?",
            preferenceKey: "guestCount",
            inputType: .numeric,
            at: CGPoint(x: 100, y: 100)
        )
        
        let success = await model.setNumericValue(5.0, for: decision.id)
        XCTAssertTrue(success)
        
        let updatedDecision = model.nodes.first(where: { $0.id == decision.id })?.unwrapped as? DecisionNode
        XCTAssertEqual(updatedDecision?.numericValue, 5.0)
    }
    
    // MARK: - Decision Tree Navigation Tests
    
    @MainActor
    func testLinkDecisions() async throws {
        let decision1 = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        let decision2 = await model.addDecision(
            question: "What spice level?",
            preferenceKey: "spiceLevel",
            inputType: .singleChoice,
            at: CGPoint(x: 200, y: 100)
        )
        
        await model.linkDecisions(from: decision1.id, to: decision2.id)
        
        // Verify precedes edge exists
        let edge = model.edges.first(where: {
            $0.from == decision1.id && $0.target == decision2.id && $0.type == .precedes
        })
        XCTAssertNotNil(edge)
    }
    
    @MainActor
    func testGetNextDecision() async throws {
        let decision1 = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        let decision2 = await model.addDecision(
            question: "What spice level?",
            preferenceKey: "spiceLevel",
            inputType: .singleChoice,
            at: CGPoint(x: 200, y: 100)
        )
        
        await model.linkDecisions(from: decision1.id, to: decision2.id)
        
        let nextDecision = model.getNextDecision(after: decision1.id)
        XCTAssertEqual(nextDecision?.id, decision2.id)
    }
    
    // MARK: - Collect Results Tests
    
    @MainActor
    func testCollectDecisionResults() async throws {
        // Create decision tree: guests (numeric) -> protein (single) -> toppings (multi)
        let guestDecision = await model.addDecision(
            question: "How many guests?",
            preferenceKey: "guestCount",
            inputType: .numeric,
            at: CGPoint(x: 100, y: 100)
        )
        _ = await model.setNumericValue(5.0, for: guestDecision.id)
        
        let proteinDecision = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 200, y: 100)
        )
        let beef = await model.addChoice(
            to: proteinDecision.id,
            choiceText: "Beef",
            value: .string("beef"),
            at: CGPoint(x: 250, y: 150)
        )!
        _ = await model.selectChoice(beef.id, in: proteinDecision.id)
        
        let toppingsDecision = await model.addDecision(
            question: "What toppings?",
            preferenceKey: "toppings",
            inputType: .multiChoice,
            at: CGPoint(x: 300, y: 100)
        )
        let lettuce = await model.addChoice(
            to: toppingsDecision.id,
            choiceText: "Lettuce",
            value: .string("lettuce"),
            at: CGPoint(x: 350, y: 150)
        )!
        let tomato = await model.addChoice(
            to: toppingsDecision.id,
            choiceText: "Tomato",
            value: .string("tomato"),
            at: CGPoint(x: 400, y: 150)
        )!
        _ = await model.selectChoice(lettuce.id, in: toppingsDecision.id)
        _ = await model.selectChoice(tomato.id, in: toppingsDecision.id)
        
        // Link them
        await model.linkDecisions(from: guestDecision.id, to: proteinDecision.id)
        await model.linkDecisions(from: proteinDecision.id, to: toppingsDecision.id)
        
        // Collect results
        let results = model.collectDecisionResults(startingFrom: guestDecision.id)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results["guestCount"], .number(5.0))
        XCTAssertEqual(results["protein"], .string("beef"))
        XCTAssertEqual(results["toppings"], .stringArray(["lettuce", "tomato"]))
    }
    
    // MARK: - Preference Node Tests
    
    @MainActor
    func testCreatePreference() async throws {
        let preference = await model.createPreference(
            name: "Taco Night Config",
            guestCount: 5,
            dinnerTime: Date(),
            preferences: ["protein": .string("beef"), "spiceLevel": .string("mild")],
            at: CGPoint(x: 100, y: 100)
        )
        
        XCTAssertEqual(preference.name, "Taco Night Config")
        XCTAssertEqual(preference.guestCount, 5)
        XCTAssertEqual(preference.preferences["protein"], .string("beef"))
        XCTAssertEqual(preference.preferences["spiceLevel"], .string("mild"))
    }
    
    @MainActor
    func testGeneratePreference() async throws {
        // Build simple decision tree
        let decision = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 100, y: 100)
        )
        let beef = await model.addChoice(
            to: decision.id,
            choiceText: "Beef",
            value: .string("beef"),
            at: CGPoint(x: 150, y: 150)
        )!
        _ = await model.selectChoice(beef.id, in: decision.id)
        
        // Generate preference
        let preference = await model.generatePreference(
            from: decision.id,
            name: "Taco Config",
            guestCount: 4,
            dinnerTime: Date(),
            at: CGPoint(x: 200, y: 100)
        )
        
        XCTAssertEqual(preference.name, "Taco Config")
        XCTAssertEqual(preference.guestCount, 4)
        XCTAssertEqual(preference.preferences["protein"], .string("beef"))
        
        // Verify decidedBy edge was created
        let edge = model.edges.first(where: {
            $0.from == preference.id && $0.target == decision.id && $0.type == .decidedBy
        })
        XCTAssertNotNil(edge)
    }
}
