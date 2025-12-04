Imports System

Module Program

    Sub Main(args As String())
        Console.WriteLine(NtpTcpClient.GetDate())
        Console.WriteLine(NtpUdpClient.GetDate())
    End Sub

End Module
