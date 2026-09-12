using System.Text.Json;
using Api.Commands.PosOrderCommands;
using Api.Commands.PosOrderCommands.BatchSync;
using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// A split bill's payments travel from the terminal to the checkout VERBATIM —
/// one per guest, never grouped by their payment method.
///
/// <para>The field report of 2026-09-11: two guests paid 184.60 and 198.00, both
/// in cash, and the server banked ONE 382.60 payment. The server was still
/// running the build from before the payment list existed, so it read only
/// PaymentTypeId and the summed AmountPaid. These tests pin the two links of the
/// server side: the terminal's JSON binds to the list, and BatchSync hands that
/// list to the checkout untouched (<see cref="SplitBillCheckoutTests"/> covers
/// the checkout writing a row for each).</para>
/// </summary>
public class BatchSyncPaymentsTests : IDisposable
{
    private const int Especes = 69;

    // Exactly the shape sync_manager's `_orderToBatchJson` posts for a split
    // bill of an open order that already lives on the server.
    private const string TerminalPayload = """
        {
          "orders": [
            {
              "localId": "split-order",
              "existingServerId": 5,
              "paymentTypeId": 69,
              "amountPaid": 382.6,
              "payments": [
                { "paymentTypeId": 69, "amount": 184.6 },
                { "paymentTypeId": 69, "amount": 198.0 }
              ],
              "orderTotal": 382.6,
              "order": { "userId": 9, "warehouseId": 17 },
              "items": [],
              "discounts": []
            }
          ]
        }
        """;

    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;

    public BatchSyncPaymentsTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _options = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_connection).Options;
        using var db = new AppDbContext(_options);
        db.Database.EnsureCreated();
    }

    public void Dispose()
    {
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }

    private static BatchSyncPosOrdersRequest Bind() =>
        JsonSerializer.Deserialize<BatchSyncPosOrdersRequest>(
            TerminalPayload, new JsonSerializerOptions(JsonSerializerDefaults.Web))!;

    [Fact]
    public void The_terminals_payload_binds_every_payment()
    {
        var order = Bind().Orders.Single();

        Assert.Equal(2, order.Payments.Count);
        Assert.All(order.Payments, p => Assert.Equal(Especes, p.PaymentTypeId));
        Assert.Equal([184.6m, 198.0m], order.Payments.Select(p => p.Amount));
    }

    [Fact]
    public async Task BatchSync_hands_the_checkout_every_payment_as_sent()
    {
        var mediator = new CapturingMediator();
        await using var db = new AppDbContext(_options);
        var handler = new BatchSyncPosOrdersCommand.Handler(
            mediator, db, NullLogger<BatchSyncPosOrdersCommand.Handler>.Instance);

        var response = await handler.Handle(
            new BatchSyncPosOrdersCommand(Bind(), companyId: 25), default);

        Assert.True(response.Results.Single().Success);
        var checkout = Assert.Single(mediator.Sent.OfType<CheckoutPosOrderCommand>()).Request;
        Assert.Equal(2, checkout.Payments.Count);
        Assert.All(checkout.Payments, p => Assert.Equal(Especes, p.PaymentTypeId));
        Assert.Equal([184.6m, 198.0m], checkout.Payments.Select(p => p.Amount));
    }

    /// <summary>Records what the handler sends and answers a checkout.</summary>
    private sealed class CapturingMediator : IMediator
    {
        public List<object> Sent { get; } = new();

        public Task<TResponse> Send<TResponse>(
            IRequest<TResponse> request, CancellationToken cancellationToken = default)
        {
            Sent.Add(request);
            object result = request switch
            {
                CheckoutPosOrderCommand => new CheckoutResult { DocumentId = 216 },
                _ => throw new NotSupportedException(request.GetType().Name),
            };
            return Task.FromResult((TResponse)result);
        }

        public Task Send<TRequest>(TRequest request, CancellationToken cancellationToken = default)
            where TRequest : IRequest => throw new NotSupportedException();

        public Task<object?> Send(object request, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public IAsyncEnumerable<TResponse> CreateStream<TResponse>(
            IStreamRequest<TResponse> request, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public IAsyncEnumerable<object?> CreateStream(
            object request, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task Publish(object notification, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task Publish<TNotification>(
            TNotification notification, CancellationToken cancellationToken = default)
            where TNotification : INotification => throw new NotSupportedException();
    }
}
