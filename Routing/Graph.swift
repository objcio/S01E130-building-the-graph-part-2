//
//  Graph.swift
//  Routing
//
//  Created by Chris Eidhof on 22.11.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

protocol Vector2 {
    associatedtype Component: Numeric
    var x: Component { get }
    var y: Component { get }
    init(x: Component, y: Component)
}

extension CGPoint: Vector2 {}

extension Vector2 {
    func dot(_ other: Self) -> Component {
        return (x * other.x) + (y * other.y)
    }
    
    static func -(l: Self, r: Self) -> Self {
        return Self(x: l.x-r.x, y: l.y-r.y)
    }
    
    static func +(l: Self, r: Self) -> Self {
        return Self(x: l.x+r.x, y: l.y+r.y)
    }
    
    static func *(l: Component, r: Self) -> Self {
        return Self(x: l*r.x, y: l*r.y)
    }
}

extension Vector2 where Component: FloatingPoint{
    func closestPoint(on lineSegment: (Self, Self)) -> Self {
        let s1 = lineSegment.0
        let s2 = lineSegment.1 - s1
        let p = self - s1
        let lambda = s2.dot(p) / s2.dot(s2)
        let clamped = min(1, max(0, lambda))
        return s1 + clamped * s2
    }
}

import CoreLocation

// This is *not* a euclidian space, but it works well enough for this specific application.
extension Coordinate: Vector2 {
    var x: Double { return longitude }    
    var y: Double { return latitude }
    
    typealias Component = Double
    
    init(x: Component, y: Component) {
        self.init(latitude: y, longitude: x)
    }
}

struct Graph {
    struct Destination {
        var coordinate: Coordinate
        var distance: CLLocationDistance
    }
    private(set) var edges: [Coordinate:[Destination]] = [:]
    
    mutating func addEdge(from: Coordinate, to: Coordinate) {
        let dist = from.distance(to: to)
        edges[from, default: []].append(Destination(coordinate: to, distance: dist))
    }
}

extension Graph {
    func debug_connectedVertices(vertex from: Coordinate) -> [[(Coordinate, Coordinate)]] {
        var result: [[(Coordinate, Coordinate)]] = [[]]
        var seen: Set<Coordinate> = []
        
        var sourcePoints = [from]
        while !sourcePoints.isEmpty {
            var newSourcePoints: [Coordinate] = []
            for source in sourcePoints {
                seen.insert(source)
                for edge in edges[source] ?? [] {
                    result[result.endIndex-1].append((source, edge.coordinate))
                    newSourcePoints.append(edge.coordinate)
                }
            }
            result.append([])
            sourcePoints = newSourcePoints.filter { !seen.contains($0) }
        }
        
        return result
    }
}

extension Graph {
    func closeEnough(to coord: Coordinate) -> Coordinate {
        let epsilon = 7 as CLLocationDistance
        guard !edges.isEmpty else { return coord }
        let segments = edges.flatMap { sourceDests in
            sourceDests.value.map { dest in
                (sourceDests.key, dest.coordinate)
            }
        }
        let mapped = segments.map { seg in
            (seg, distance: coord.distance(to: seg))
        }
        let (segment, distance) = mapped.min(by: { $0.distance < $1.distance })!
        if distance < epsilon {
            return segment.0 // todo return closest point on segment (and add to the graph)
        } else {
            return coord
        }
    }
}

extension Coordinate {
    func distance(to: (Coordinate, Coordinate)) -> CLLocationDistance {
        return distance(to: closestPoint(on: to))
    }
}

func buildGraph(tracks: [Track]) -> Graph {
    var result = Graph()
    for track in tracks {
        let copy = result
        for (from, to) in zip(track.coordinates, track.coordinates.dropFirst() + [track.coordinates[0]]) {
            result.addEdge(from: copy.closeEnough(to: from.coordinate), to: copy.closeEnough(to: to.coordinate))
        }
    }
    return result
}

