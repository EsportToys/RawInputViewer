
# RawInputViewer
Examine the raw contents of `WM_INPUT` messages (RawInput API) in realtime.

![mouse][mouse-img]![devices][devices-img]
![hid][hid-img]
![keyboard][keyboard-img]



## How games and programs receives input
1. Every GUI program running on Windows is given a Message Queue by the OS, essentially a "mailbox" which the program is obliged to regularly check and acknowledge recipt of every message, otherwise they will be forcefully terminated by Windows if it don't hear from them for too long. These message are things like "the user clicked on this button" or "the user minimized this window" etc.
2. For every message posted to the program, the program can ask Windows about miscellaneous details about it, such as when the message was posted to its inbox, the location of the mouse cursor when it was posted, or info pertaining specifically to that specific message type.
3. Once the program has asked enough about the message, it should tell the OS "I'm done with this message" and Windows will remove the message from its inbox.

## How RawInput works in games and programs
1. the game/program tells Windows that it wishes to subscribe to certain types of devices (mice, keyboards, joysticks, volume controls, etc., specified by UsagePage & UsageID), Windows will then start posting `WM_INPUT` messages to its inbox.
2. `WM_INPUT` messages contains a handle for retreiving the content of the input, essentially just a pickup notice saying "you got a package at the post office, please come pick it up using this number".
3. When the program wants to retrieve the actual rawinput content it first needs to ask for the header, which contains information about the generic type of input it is from, the device handle it was sent from, and how large the content is (Essentially asking "How big is the package and what shape of bag do I need to bring?" as well as "What is the sender's phone number, in case I need more info about who sent it?").
4. The program prepares the appropriate container, and asks Windows for the actual content of that specific message. Alternatively, the program can tell Windows that it wishes to pick up all of its other pending package at the same time, in which case step 3 would instead be asking how large of a bag it needs to bring to pick up all of the pending packages. The pickup notices (`WM_INPUT`) for those packages is automatically cleared from the inbox so the program only needs to visit the post office once (of course, it loses the ability to ask the miscellaneous information about those packages individually).
5. If the generic type of input is neither mouse nor keyboard (such as joysticks etc.) then the program will also need to ask Windows about what format the input is packaged in, so that it actually knows how to unpack it once retrieved.

[mouse-img]: https://user-images.githubusercontent.com/98432183/152683848-dfba3b80-e75d-4563-98c8-05cee30436e3.png
[keyboard-img]: https://user-images.githubusercontent.com/98432183/152683829-7f481f59-ae19-4353-a6b9-40955658d6fa.png
[hid-img]: https://user-images.githubusercontent.com/98432183/152684845-21877dea-2870-4136-bf13-20228877dfd0.png
[devices-img]: https://user-images.githubusercontent.com/98432183/152684987-2adb889f-d52e-4915-b011-4262df044ff6.png

