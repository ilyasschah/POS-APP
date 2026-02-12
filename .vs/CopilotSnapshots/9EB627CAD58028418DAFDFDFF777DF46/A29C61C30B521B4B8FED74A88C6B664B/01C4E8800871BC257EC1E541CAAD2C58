using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosVoidQuery;

    public class GetPosVoidByIdQuery : IRequest<PosVoidDto?>
    {
        public int Id { get; set; }

        // Nested Handler
        public class GetPosVoidByIdQueryHandler : IRequestHandler<GetPosVoidByIdQuery, PosVoidDto?>
        {
            private readonly PosVoidRepository _repository;

            public GetPosVoidByIdQueryHandler(PosVoidRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosVoidDto?> Handle(GetPosVoidByIdQuery request, CancellationToken cancellationToken)
            {
                var v = await _repository.GetByIdAsync(request.Id);
                if (v == null)
                {
                    return null;
                }

                return new PosVoidDto
                {
                    Id = v.Id,
                    OrderNumber = v.OrderNumber,
                    UserName = v.UserName,
                    ProductName = v.ProductName,
                    Quantity = v.Quantity,
                    Price = v.Price,
                    Total = v.Total,
                    IsConfirmed = v.IsConfirmed,
                    Reason = v.Reason,
                    VoidedByName = v.VoidedByName,
                    DateVoided = v.DateVoided
                };
            }
        }
    }
