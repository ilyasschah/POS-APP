using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.PaymentQuery
{
    public class GetAllPaymentsQuery : IRequest<List<PaymentDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllPaymentsQueryHandler : IRequestHandler<GetAllPaymentsQuery, List<PaymentDto>>
        {
            private readonly PaymentRepository _repository;

            public GetAllPaymentsQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PaymentDto>> Handle(GetAllPaymentsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperPayment.MapToPaymentDto).ToList();
            }
        }
    }
}