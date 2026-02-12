using MediatR;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.PosVoidQuery
{
    public class GetPosVoidsByOrderNumberQuery : IRequest<List<PosVoidDto>>
    {
        public string OrderNumber { get; set; }
        public class GetPosVoidsByOrderNumberQueryHandler : IRequestHandler<GetPosVoidsByOrderNumberQuery, List<PosVoidDto>>
        {
            private readonly PosVoidRepository _repository;

            public GetPosVoidsByOrderNumberQueryHandler(PosVoidRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PosVoidDto>> Handle(GetPosVoidsByOrderNumberQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByOrderNumberAsync(request.OrderNumber);

                return entities.Select(v => new PosVoidDto
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
                }).ToList();
            }
        }
    }
}