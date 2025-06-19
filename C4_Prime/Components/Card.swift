//
//  Card.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI

struct Card: View {
    var poseTitle: String = "Front Double\nBicep"

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)

            HStack {
                Image("placeholder_bodybuilder")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width * 0.25)
                    .clipped()
                    .cornerRadius(15)

                Spacer()
                    .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(poseTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 10)

                    NavigationLink(destination: BodyDetection()) {
                        HStack {
                            Spacer()
                            Text("Start")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)

                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.trailing, 20)

                Spacer()
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 200)
        .cornerRadius(20)
        .padding(10)
    }
}

#Preview {
    Card()
}
