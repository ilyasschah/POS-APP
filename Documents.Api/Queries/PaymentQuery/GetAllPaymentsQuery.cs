using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.PaymentQuery
{
    public class GetAllPaymentsQuery : IRequest<List<PaymentDto>>
    {
        public class GetAllPaymentsQueryHandler : IRequestHandler<GetAllPaymentsQuery, List<PaymentDto>>
        {
            private readonly PaymentRepository _repository;

            public GetAllPaymentsQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<PaymentDto>> Handle(GetAllPaymentsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperPayment.MapToPaymentDto).ToList();
            }
        }
    }
}