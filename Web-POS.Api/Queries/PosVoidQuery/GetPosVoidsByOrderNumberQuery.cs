using MediatR;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PosVoidQuery;

public class GetPosVoidsByOrderNumberQuery : IRequest<List<PosVoidDto>>
{
    public string OrderNumber { get; set; }
    public int CompanyId { get; set; }

    public GetPosVoidsByOrderNumberQuery(string orderNumber)
    {
        OrderNumber = orderNumber;
    }

    public class GetPosVoidsByOrderNumberQueryHandler : IRequestHandler<GetPosVoidsByOrderNumberQuery, List<PosVoidDto>>
    {
        private readonly PosVoidRepository _repository;

        public GetPosVoidsByOrderNumberQueryHandler(PosVoidRepository repository) => _repository = repository;

        public async Task<List<PosVoidDto>> Handle(GetPosVoidsByOrderNumberQuery request, CancellationToken cancellationToken)
        {
            var list = await _repository.GetByOrderNumberAsync(request.OrderNumber, request.CompanyId);
            return list.Select(pv => new PosVoidDto
            {
                Id = pv.Id,
                OrderNumber = pv.OrderNumber,
                UserName = pv.UserName,
                ProductName = pv.ProductName,
                Quantity = pv.Quantity,
                Price = pv.Price,
                Total = pv.Total,
                IsConfirmed = pv.IsConfirmed,
                Reason = pv.Reason,
                VoidedByName = pv.VoidedByName,
                DateVoided = pv.DateVoided
            }).ToList();
        }
    }
}